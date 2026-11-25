defmodule Oli.ScopedFeatureFlags.Audited do
  @moduledoc """
  Application boundary for audited scoped feature flags, rollout stages, and publisher
  exemptions.

  Each command writes the change and its event (`feature_flag_*` or `feature_rollout_*`) in
  the same transaction, so an audit failure rolls the change back. Setting a flag or a stage
  to the value it already has writes no event. Cache invalidation, PubSub broadcasts, and
  telemetry run after commit. Commands do not authorize the actor; callers keep their existing
  authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export Mutations. Outgoing checks are off because
  # this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Auditing
  alias Oli.Auditing.{Command, Context}
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Sections.Section
  alias Oli.ScopedFeatureFlags
  alias Oli.ScopedFeatureFlags.Audited.Mutations
  alias Oli.ScopedFeatureFlags.Rollouts

  @global_scope %{role: :scope, type: :global, id: "global", label: "All institutions"}

  ## Flags

  @doc "Enables `feature_name` for a project or section. Enabling an enabled flag writes nothing."
  @spec enable_feature(Context.t(), atom() | String.t(), %Project{} | %Section{}) ::
          {:ok, struct()} | {:error, term()}
  def enable_feature(context, feature_name, resource) do
    ScopedFeatureFlags.validate_feature_name!(feature_name)
    set_features_atomically(context, [{feature_name, true}], resource) |> single()
  end

  @doc "Disables `feature_name`. Disabling a disabled flag writes nothing and returns `{:ok, nil}`."
  @spec disable_feature(Context.t(), atom() | String.t(), %Project{} | %Section{}) ::
          {:ok, struct() | nil} | {:error, term()}
  def disable_feature(context, feature_name, resource) do
    ScopedFeatureFlags.validate_feature_name!(feature_name)
    set_features_atomically(context, [{feature_name, false}], resource) |> single()
  end

  @doc """
  Sets several flags of one project or section in one transaction (`{feature_name, enabled}`
  pairs); any failure rolls all of them back. Returns the resulting flag states in order.
  """
  @spec set_features_atomically(Context.t(), [{atom() | String.t(), boolean()}], struct()) ::
          {:ok, [struct() | nil]} | {:error, term()}
  def set_features_atomically(context, settings, resource) when is_list(settings) do
    Command.run(:flags, fn multi ->
      settings
      |> Enum.with_index()
      |> Enum.reduce(multi, fn {{name, enabled}, index}, multi ->
        flag_multi(
          multi,
          {:flag, index},
          context,
          Rollouts.normalize_feature_name(name),
          enabled,
          resource
        )
      end)
      |> Multi.run(:flags, fn _repo, changes ->
        {:ok, Enum.map(0..(length(settings) - 1)//1, &Map.fetch!(changes, {:flag, &1}))}
      end)
    end)
  end

  @doc """
  Removes the stored setting of `feature_name` and records `feature_flag_removed`. Returns
  `{:error, :not_found}` when the flag has no setting.
  """
  @spec remove_feature(Context.t(), atom() | String.t(), %Project{} | %Section{}) ::
          {:ok, struct()} | {:error, term()}
  def remove_feature(context, feature_name, resource) do
    ScopedFeatureFlags.validate_feature_name!(feature_name)
    name = Rollouts.normalize_feature_name(feature_name)

    Command.run(:flag, fn multi ->
      multi
      |> Multi.run({:flag, :state}, fn _repo, _changes ->
        case ScopedFeatureFlags.get_flag_state(name, resource) do
          nil -> {:error, :not_found}
          state -> Mutations.delete(state)
        end
      end)
      |> Auditing.append({:flag, :event}, fn _changes ->
        flag_event(context, :feature_flag_removed, name, resource, nil)
      end)
      |> Multi.run(:flag, fn _repo, changes -> {:ok, Map.fetch!(changes, {:flag, :state})} end)
    end)
  end

  # Each flag stores its resulting state under `step`; `{step, :write}` keeps whether it changed.
  defp flag_multi(multi, step, context, name, enabled, resource) do
    multi
    |> Multi.run({step, :write}, fn _repo, _changes ->
      with :ok <- ScopedFeatureFlags.validate_flag_write(name, resource) do
        case {ScopedFeatureFlags.get_flag_state(name, resource), enabled} do
          {nil, true} ->
            with {:ok, state} <- Mutations.insert_flag(name, resource),
                 do: {:ok, {:changed, state}}

          {nil, false} ->
            {:ok, {:unchanged, nil}}

          {state, true} ->
            {:ok, {:unchanged, state}}

          {state, false} ->
            with {:ok, state} <- Mutations.delete(state), do: {:ok, {:changed, state}}
        end
      end
    end)
    |> Auditing.append({step, :event}, fn changes ->
      case Map.fetch!(changes, {step, :write}) do
        {:unchanged, _state} ->
          :skip

        {:changed, _state} ->
          flag_event(context, flag_event_type(enabled), name, resource, enabled)
      end
    end)
    |> Multi.run(step, fn _repo, changes ->
      {_change, state} = Map.fetch!(changes, {step, :write})
      {:ok, state}
    end)
  end

  defp single({:ok, [state]}), do: {:ok, state}
  defp single(error), do: error

  defp flag_event_type(true), do: :feature_flag_enabled
  defp flag_event_type(false), do: :feature_flag_disabled

  defp flag_event(context, event_type, name, resource, enabled) do
    {scope, scope_key, details} =
      case resource do
        %Project{id: id, title: title} ->
          {%{project_id: id}, "project_#{id}",
           %{"resource_type" => "project", "project_title" => title}}

        %Section{id: id, title: title} ->
          {%{section_id: id}, "section_#{id}",
           %{"resource_type" => "section", "section_title" => title}}
      end

    Auditing.build(context, %{
      event_type: event_type,
      entity: {:feature_flag, name, %{}},
      scope: scope,
      event_key: "flag:#{key_segment(name)}:#{scope_key}:#{event_type}",
      details: Map.merge(details, %{"feature_name" => name, "enabled" => enabled})
    })
  end

  ## Rollouts

  @doc """
  Creates or updates the rollout stage of `feature_name` for a scope (`:global`, `:project`, or
  `:section` with its ID) and records `feature_rollout_stage_changed`. Setting the current stage
  again writes nothing. Option `:note` is recorded with the event.
  """
  @spec upsert_rollout(
          Context.t(),
          atom() | String.t(),
          atom(),
          pos_integer() | nil,
          atom(),
          keyword()
        ) ::
          {:ok, struct()} | {:error, term()}
  def upsert_rollout(context, feature_name, scope_type, scope_id, stage, opts \\ []) do
    name = Rollouts.normalize_feature_name(feature_name)
    scope_type = Rollouts.normalize_scope_type(scope_type)
    scope_id = Rollouts.normalize_scope_id(scope_type, scope_id)
    stage = Rollouts.normalize_stage(stage)

    attrs = %{
      feature_name: name,
      scope_type: scope_type,
      scope_id: scope_id,
      stage: stage,
      rollout_percentage: Rollouts.stage_percentage(stage),
      updated_by_author_id: context.author_id
    }

    Command.run(:rollout, fn multi ->
      multi
      |> Multi.run({:rollout, :previous}, fn _repo, _changes ->
        {:ok, Mutations.lock_rollout(name, scope_type, scope_id)}
      end)
      |> Multi.run({:rollout, :saved}, fn _repo, changes ->
        Mutations.put_rollout(Map.fetch!(changes, {:rollout, :previous}), attrs)
      end)
      |> Auditing.append({:rollout, :event}, fn changes ->
        previous = Map.fetch!(changes, {:rollout, :previous})
        rollout = Map.fetch!(changes, {:rollout, :saved})

        case previous do
          %{stage: ^stage} ->
            :skip

          _changed ->
            rollout_event(context, :feature_rollout_stage_changed, rollout, %{
              "stage" => Atom.to_string(rollout.stage),
              "rollout_percentage" => rollout.rollout_percentage,
              "previous" =>
                previous && %{"stage" => Atom.to_string(previous.stage), "effect" => nil},
              "note" => Keyword.get(opts, :note)
            })
        end
      end)
      |> Multi.run(:rollout, fn _repo, changes ->
        {:ok,
         {Map.fetch!(changes, {:rollout, :previous}), Map.fetch!(changes, {:rollout, :saved})}}
      end)
    end)
    |> case do
      {:ok, {previous, rollout}} ->
        Rollouts.stage_changed(previous, rollout, actor_id(context))
        {:ok, rollout}

      error ->
        error
    end
  end

  @doc "Deletes the rollout of `feature_name` for a scope and records the deletion."
  @spec delete_rollout(Context.t(), atom() | String.t(), atom(), pos_integer() | nil, keyword()) ::
          :ok | {:error, term()}
  def delete_rollout(context, feature_name, scope_type, scope_id, opts \\ []) do
    name = Rollouts.normalize_feature_name(feature_name)
    scope_type = Rollouts.normalize_scope_type(scope_type)
    scope_id = Rollouts.normalize_scope_id(scope_type, scope_id)

    Command.run(:rollout, fn multi ->
      multi
      |> Multi.run(:rollout, fn _repo, _changes ->
        case Mutations.lock_rollout(name, scope_type, scope_id) do
          nil -> {:error, :not_found}
          rollout -> Mutations.delete(rollout)
        end
      end)
      |> Auditing.append({:rollout, :event}, fn %{rollout: rollout} ->
        rollout_event(context, :feature_rollout_stage_deleted, rollout, %{
          "stage" => Atom.to_string(rollout.stage),
          "note" => Keyword.get(opts, :note)
        })
      end)
    end)
    |> case do
      {:ok, rollout} ->
        Rollouts.stage_deleted(rollout, actor_id(context))
        :ok

      error ->
        error
    end
  end

  @doc """
  Creates or updates the exemption of a publisher from `feature_name` and records
  `feature_rollout_exemption_upserted`. Setting the current effect again writes nothing.
  """
  @spec upsert_exemption(Context.t(), atom() | String.t(), pos_integer(), atom(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def upsert_exemption(context, feature_name, publisher_id, effect, opts \\ []) do
    name = Rollouts.normalize_feature_name(feature_name)
    effect = Rollouts.normalize_effect(effect)

    attrs = %{
      feature_name: name,
      publisher_id: publisher_id,
      effect: effect,
      updated_by_author_id: context.author_id,
      note: Keyword.get(opts, :note)
    }

    Command.run(:exemption, fn multi ->
      multi
      |> Multi.run({:exemption, :previous}, fn _repo, _changes ->
        {:ok, Mutations.lock_exemption(name, publisher_id)}
      end)
      |> Multi.run(:exemption, fn _repo, changes ->
        Mutations.put_exemption(Map.fetch!(changes, {:exemption, :previous}), attrs)
      end)
      |> Auditing.append({:exemption, :event}, fn changes ->
        case Map.fetch!(changes, {:exemption, :previous}) do
          %{effect: ^effect, note: note} when note == attrs.note ->
            :skip

          previous ->
            exemption_event(
              context,
              :feature_rollout_exemption_upserted,
              Map.fetch!(changes, :exemption),
              %{
                "previous" =>
                  previous && %{"stage" => nil, "effect" => Atom.to_string(previous.effect)},
                "note" => Keyword.get(opts, :note)
              }
            )
        end
      end)
    end)
    |> case do
      {:ok, exemption} ->
        Rollouts.exemption_changed(exemption)
        {:ok, exemption}

      error ->
        error
    end
  end

  @doc "Removes the exemption of a publisher from `feature_name` and records the deletion."
  @spec delete_exemption(Context.t(), atom() | String.t(), pos_integer(), keyword()) ::
          :ok | {:error, term()}
  def delete_exemption(context, feature_name, publisher_id, opts \\ []) do
    name = Rollouts.normalize_feature_name(feature_name)

    Command.run(:exemption, fn multi ->
      multi
      |> Multi.run(:exemption, fn _repo, _changes ->
        case Mutations.lock_exemption(name, publisher_id) do
          nil -> {:error, :not_found}
          exemption -> Mutations.delete(exemption)
        end
      end)
      |> Auditing.append({:exemption, :event}, fn %{exemption: exemption} ->
        exemption_event(context, :feature_rollout_exemption_deleted, exemption, %{
          "note" => Keyword.get(opts, :note)
        })
      end)
    end)
    |> case do
      {:ok, exemption} ->
        Rollouts.exemption_deleted(exemption, actor_id(context))
        :ok

      error ->
        error
    end
  end

  defp rollout_event(context, event_type, rollout, details) do
    {scope, refs, scope_key} =
      case {rollout.scope_type, rollout.scope_id} do
        {:project, id} -> {%{project_id: id}, [], "project_#{id}"}
        {:section, id} -> {%{section_id: id}, [], "section_#{id}"}
        _global -> {%{}, [@global_scope], "global"}
      end

    action = event_type |> Atom.to_string() |> String.replace_prefix("feature_rollout_", "")

    Auditing.build(context, %{
      event_type: event_type,
      entity: {:feature_rollout, rollout.feature_name, %{}},
      scope: scope,
      refs: refs,
      event_key: "rollout:#{key_segment(rollout.feature_name)}:#{scope_key}:#{action}",
      details:
        details
        |> Map.merge(%{
          "feature_name" => rollout.feature_name,
          "scope_type" => Atom.to_string(rollout.scope_type),
          "scope_id" => rollout.scope_id
        })
        |> drop_nil()
    })
  end

  defp exemption_event(context, event_type, exemption, details) do
    action = event_type |> Atom.to_string() |> String.replace_prefix("feature_rollout_", "")

    Auditing.build(context, %{
      event_type: event_type,
      entity:
        {:rollout_exemption, "#{exemption.feature_name}:publisher:#{exemption.publisher_id}", %{}},
      refs: [%{role: :scope, type: :publisher, id: exemption.publisher_id}],
      event_key:
        "rollout:#{key_segment(exemption.feature_name)}:publisher_#{exemption.publisher_id}:#{action}",
      details:
        details
        |> Map.merge(%{
          "feature_name" => exemption.feature_name,
          "publisher_id" => exemption.publisher_id,
          "effect" => Atom.to_string(exemption.effect)
        })
        |> drop_nil()
    })
  end

  defp drop_nil(details), do: Map.reject(details, fn {_key, value} -> is_nil(value) end)

  defp actor_id(%Context{actor_type: :author, author_id: id}), do: {:author, id}
  defp actor_id(%Context{actor_type: :user, user_id: id}), do: {:user, id}
  defp actor_id(_context), do: nil

  # Event key segments only allow lowercase letters, digits, underscores, and hyphens.
  defp key_segment(value),
    do: value |> to_string() |> String.downcase() |> String.replace(~r/[^a-z0-9_\-]/, "_")
end
