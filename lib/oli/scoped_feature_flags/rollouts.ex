defmodule Oli.ScopedFeatureFlags.Rollouts do
  @moduledoc """
  Persistence and auditing helpers for scoped feature flag rollouts and publisher exemptions.

  This module encapsulates the CRUD operations used by the canary rollout layer,
  ensuring changes are audited, telemetry is emitted, and cache invalidations are broadcast.
  """

  import Ecto.Query, warn: false

  require Logger

  alias Oli.Auditing
  alias Oli.Repo
  alias Oli.ScopedFeatureFlags.ScopedFeatureExemption
  alias Oli.ScopedFeatureFlags.ScopedFeatureRollout

  @pubsub_topic "feature_rollouts"

  @stage_percentages %{
    off: 0,
    internal_only: 0,
    five_percent: 5,
    fifty_percent: 50,
    full: 100
  }

  @type scope_type :: :global | :project | :section

  @doc """
  Returns the current rollout record for the given feature/scope combination.
  """
  @spec get_rollout(String.t() | atom(), scope_type(), integer() | nil) ::
          ScopedFeatureRollout.t() | nil
  def get_rollout(feature_name, scope_type, scope_id \\ nil) do
    feature_name = normalize_feature_name(feature_name)
    scope_type = normalize_scope_type(scope_type)
    scope_id = normalize_scope_id(scope_type, scope_id)

    ScopedFeatureRollout
    |> where(
      [r],
      r.feature_name == ^feature_name and r.scope_type == ^scope_type and
        r.scope_id == ^scope_id
    )
    |> Repo.one()
  end

  @doc """
  Lists all rollout records for a given feature.
  """
  @spec list_rollouts(String.t() | atom()) :: [ScopedFeatureRollout.t()]
  def list_rollouts(feature_name) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureRollout
    |> where([r], r.feature_name == ^feature_name)
    |> order_by([r], asc: r.scope_type, asc_nulls_first: r.scope_id)
    |> Repo.all()
  end

  @doc """
  Creates or updates a rollout stage for the provided scope.

  ## Options
    * `:note` - free-form explanation recorded with the audit trail.
  """
  @spec upsert_rollout(
          String.t() | atom(),
          scope_type(),
          integer() | nil,
          ScopedFeatureRollout.stage(),
          Oli.Accounts.Author.t() | nil,
          keyword()
        ) ::
          {:ok, ScopedFeatureRollout.t()}
          | {:error, Ecto.Changeset.t()}
  def upsert_rollout(feature_name, scope_type, scope_id, stage, actor, opts \\ []) do
    feature_name = normalize_feature_name(feature_name)
    scope_type = normalize_scope_type(scope_type)
    scope_id = normalize_scope_id(scope_type, scope_id)
    stage = normalize_stage(stage)
    attrs = rollout_attrs(feature_name, scope_type, scope_id, stage, actor)

    Repo.transaction(fn ->
      existing = get_rollout(feature_name, scope_type, scope_id)

      case persist_rollout(existing, attrs) do
        {:ok, rollout} ->
          maybe_audit_stage_change(existing, rollout, actor, opts)
          {existing, rollout}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {previous, rollout}} ->
        maybe_emit_stage_changed_telemetry(previous, rollout, actor)
        broadcast_stage_invalidation(feature_name, scope_type, scope_id)
        {:ok, rollout}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Deletes a rollout record for the provided scope.
  """
  @spec delete_rollout(
          String.t() | atom(),
          scope_type(),
          integer() | nil,
          Oli.Accounts.Author.t() | nil,
          keyword()
        ) ::
          :ok | {:error, :not_found}
  def delete_rollout(feature_name, scope_type, scope_id, actor, opts \\ []) do
    feature_name = normalize_feature_name(feature_name)
    scope_type = normalize_scope_type(scope_type)
    scope_id = normalize_scope_id(scope_type, scope_id)

    Repo.transaction(fn ->
      case get_rollout(feature_name, scope_type, scope_id) do
        nil ->
          Repo.rollback(:not_found)

        rollout ->
          case Repo.delete(rollout) do
            {:ok, _} ->
              maybe_audit_rollout_delete(rollout, actor, opts)
              rollout

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
      end
    end)
    |> case do
      {:ok, rollout} ->
        broadcast_stage_invalidation(feature_name, scope_type, scope_id)
        :telemetry.execute(
          [:torus, :feature_flag, :rollout_stage_deleted],
          %{count: 1},
          %{
            feature: rollout.feature_name,
            scope_type: rollout.scope_type,
            scope_id: rollout.scope_id,
            stage: rollout.stage,
            actor_id: actor_identifier(actor)
          }
        )

        :ok

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, %Ecto.Changeset{} = changeset} ->
        Logger.warning(
          "Failed to delete rollout for #{feature_name}/#{scope_type}/#{inspect(scope_id)}: #{inspect(changeset.errors)}"
        )

        {:error, :not_found}
    end
  end

  @doc """
  Retrieves the exemption record for a feature/publisher combination.
  """
  @spec get_exemption(String.t() | atom(), pos_integer()) ::
          ScopedFeatureExemption.t() | nil
  def get_exemption(feature_name, publisher_id) when is_integer(publisher_id) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureExemption
    |> where([e], e.feature_name == ^feature_name and e.publisher_id == ^publisher_id)
    |> Repo.one()
  end

  @doc """
  Lists all exemptions for a given feature.
  """
  @spec list_exemptions(String.t() | atom()) :: [ScopedFeatureExemption.t()]
  def list_exemptions(feature_name) do
    feature_name = normalize_feature_name(feature_name)

    ScopedFeatureExemption
    |> where([e], e.feature_name == ^feature_name)
    |> order_by([e], asc: e.publisher_id)
    |> Repo.all()
  end

  @doc """
  Creates or updates an exemption for a publisher.
  """
  @spec upsert_exemption(
          String.t() | atom(),
          pos_integer(),
          ScopedFeatureExemption.effect(),
          Oli.Accounts.Author.t() | nil,
          keyword()
        ) ::
          {:ok, ScopedFeatureExemption.t()} | {:error, Ecto.Changeset.t()}
  def upsert_exemption(feature_name, publisher_id, effect, actor, opts \\ []) do
    feature_name = normalize_feature_name(feature_name)
    effect = normalize_effect(effect)
    attrs = %{
      feature_name: feature_name,
      publisher_id: publisher_id,
      effect: effect,
      updated_by_author_id: maybe_author_id(actor),
      note: Keyword.get(opts, :note)
    }

    Repo.transaction(fn ->
      existing = get_exemption(feature_name, publisher_id)

      case persist_exemption(existing, attrs) do
        {:ok, exemption} ->
          maybe_audit_exemption(existing, exemption, actor, opts)
          {existing, exemption}

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, {_previous, exemption}} ->
        broadcast_exemption_invalidation(feature_name, publisher_id)
        {:ok, exemption}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Removes an exemption record.
  """
  @spec delete_exemption(
          String.t() | atom(),
          pos_integer(),
          Oli.Accounts.Author.t() | nil,
          keyword()
        ) ::
          :ok | {:error, :not_found}
  def delete_exemption(feature_name, publisher_id, actor, opts \\ []) do
    feature_name = normalize_feature_name(feature_name)

    Repo.transaction(fn ->
      case get_exemption(feature_name, publisher_id) do
        nil ->
          Repo.rollback(:not_found)

        exemption ->
          case Repo.delete(exemption) do
            {:ok, _} ->
              maybe_audit_exemption_delete(exemption, actor, opts)
              exemption

            {:error, changeset} ->
              Repo.rollback(changeset)
          end
      end
    end)
    |> case do
      {:ok, exemption} ->
        broadcast_exemption_invalidation(feature_name, publisher_id)
        :telemetry.execute(
          [:torus, :feature_flag, :rollout_exemption_deleted],
          %{count: 1},
          %{
            feature: exemption.feature_name,
            publisher_id: exemption.publisher_id,
            effect: exemption.effect,
            actor_id: actor_identifier(actor)
          }
        )

        :ok

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, %Ecto.Changeset{}} ->
        {:error, :not_found}
    end
  end

  defp persist_rollout(nil, attrs) do
    %ScopedFeatureRollout{}
    |> ScopedFeatureRollout.changeset(attrs)
    |> Repo.insert()
  end

  defp persist_rollout(%ScopedFeatureRollout{} = rollout, attrs) do
    rollout
    |> ScopedFeatureRollout.changeset(attrs)
    |> Repo.update()
  end

  defp persist_exemption(nil, attrs) do
    %ScopedFeatureExemption{}
    |> ScopedFeatureExemption.changeset(attrs)
    |> Repo.insert()
  end

  defp persist_exemption(%ScopedFeatureExemption{} = exemption, attrs) do
    exemption
    |> ScopedFeatureExemption.changeset(attrs)
    |> Repo.update()
  end

  defp rollout_attrs(feature_name, scope_type, scope_id, stage, actor) do
    %{
      feature_name: feature_name,
      scope_type: scope_type,
      scope_id: scope_id,
      stage: stage,
      rollout_percentage: Map.fetch!(@stage_percentages, stage),
      updated_by_author_id: maybe_author_id(actor)
    }
  end

  defp maybe_audit_stage_change(previous, rollout, actor, opts) do
    note = Keyword.get(opts, :note)

    details =
      %{
        "feature_name" => rollout.feature_name,
        "scope_type" => Atom.to_string(rollout.scope_type),
        "scope_id" => rollout.scope_id,
        "stage" => Atom.to_string(rollout.stage),
        "rollout_percentage" => rollout.rollout_percentage
      }
      |> maybe_put_previous(previous)
      |> maybe_put_note(note)

    capture_audit(actor, :feature_rollout_stage_changed, nil, details)
  end

  defp maybe_audit_rollout_delete(rollout, actor, opts) do
    note = Keyword.get(opts, :note)

    details =
      %{
        "feature_name" => rollout.feature_name,
        "scope_type" => Atom.to_string(rollout.scope_type),
        "scope_id" => rollout.scope_id,
        "stage" => Atom.to_string(rollout.stage)
      }
      |> maybe_put_note(note)

    capture_audit(actor, :feature_rollout_stage_deleted, nil, details)
  end

  defp maybe_audit_exemption(previous, exemption, actor, opts) do
    note = Keyword.get(opts, :note)

    details =
      %{
        "feature_name" => exemption.feature_name,
        "publisher_id" => exemption.publisher_id,
        "effect" => Atom.to_string(exemption.effect)
      }
      |> maybe_put_previous(previous)
      |> maybe_put_note(note)

    capture_audit(actor, :feature_rollout_exemption_upserted, nil, details)
  end

  defp maybe_audit_exemption_delete(exemption, actor, opts) do
    note = Keyword.get(opts, :note)

    details =
      %{
        "feature_name" => exemption.feature_name,
        "publisher_id" => exemption.publisher_id,
        "effect" => Atom.to_string(exemption.effect)
      }
      |> maybe_put_note(note)

    capture_audit(actor, :feature_rollout_exemption_deleted, nil, details)
  end

  defp maybe_put_previous(details, nil), do: details

  defp maybe_put_previous(details, previous) do
    Map.put(details, "previous", %{
      "stage" =>
        previous
        |> Map.get(:stage)
        |> maybe_atom_to_string(),
      "effect" =>
        previous
        |> Map.get(:effect)
        |> maybe_atom_to_string()
    })
  end

  defp maybe_put_note(details, nil), do: details
  defp maybe_put_note(details, note), do: Map.put(details, "note", note)

  defp capture_audit(nil, _event_type, _resource, _details), do: :ok

  defp capture_audit(actor, event_type, resource, details) do
    case Auditing.capture(actor, event_type, resource, details) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp maybe_emit_stage_changed_telemetry(previous, rollout, actor) do
    metadata = %{
      feature: rollout.feature_name,
      scope_type: rollout.scope_type,
      scope_id: rollout.scope_id,
      from_stage: previous && previous.stage,
      to_stage: rollout.stage,
      actor_id: actor_identifier(actor)
    }

    :telemetry.execute([:torus, :feature_flag, :rollout_stage_changed], %{count: 1}, metadata)
  end

  defp broadcast_stage_invalidation(feature_name, scope_type, scope_id) do
    Cachex.del(:feature_flag_stage, {:stage, feature_name, scope_type, scope_id})

    Phoenix.PubSub.broadcast(
      Oli.PubSub,
      @pubsub_topic,
      {:stage_invalidated, feature_name, scope_type, scope_id}
    )
  end

  defp broadcast_exemption_invalidation(feature_name, publisher_id) do
    Cachex.del(:feature_flag_stage, {:exemption, feature_name, publisher_id})

    Phoenix.PubSub.broadcast(
      Oli.PubSub,
      @pubsub_topic,
      {:exemption_invalidated, feature_name, publisher_id}
    )
  end

  defp normalize_feature_name(feature) when is_atom(feature), do: Atom.to_string(feature)
  defp normalize_feature_name(feature) when is_binary(feature), do: feature

  defp normalize_scope_type(scope_type) do
    valid = ScopedFeatureRollout.scope_types()

    if Enum.member?(valid, scope_type) do
      scope_type
    else
      raise ArgumentError,
            "Invalid scope_type #{inspect(scope_type)}. Expected one of #{inspect(valid)}."
    end
  end

  defp normalize_stage(stage) do
    valid = ScopedFeatureRollout.stages()

    if Enum.member?(valid, stage) do
      stage
    else
      raise ArgumentError,
            "Invalid rollout stage #{inspect(stage)}. Expected one of #{inspect(valid)}."
    end
  end

  defp normalize_scope_id(:global, _scope_id), do: nil
  defp normalize_scope_id(_scope_type, scope_id) when is_integer(scope_id) and scope_id > 0, do: scope_id

  defp normalize_scope_id(scope_type, scope_id) do
    raise ArgumentError,
          "Invalid scope_id #{inspect(scope_id)} for scope type #{inspect(scope_type)}"
  end

  defp normalize_effect(effect) do
    valid = ScopedFeatureExemption.effects()

    if Enum.member?(valid, effect) do
      effect
    else
      raise ArgumentError,
            "Invalid exemption effect #{inspect(effect)}. Expected one of #{inspect(valid)}."
    end
  end

  defp maybe_atom_to_string(nil), do: nil
  defp maybe_atom_to_string(value) when is_atom(value), do: Atom.to_string(value)
  defp maybe_atom_to_string(value), do: value

  defp maybe_author_id(%{id: id, __struct__: Oli.Accounts.Author}), do: id
  defp maybe_author_id(_), do: nil

  defp actor_identifier(%Oli.Accounts.Author{id: id}), do: {:author, id}
  defp actor_identifier(%Oli.Accounts.User{id: id}), do: {:user, id}
  defp actor_identifier(_), do: nil
end
