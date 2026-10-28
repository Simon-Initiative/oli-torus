defmodule Oli.GenAI.Configuration do
  @moduledoc "Transactional Provider configuration and probe-model designation behind the GenAI context."
  import Ecto.Query
  import Ecto.Changeset
  alias Oli.GenAI.{Provider, Completions.RegisteredModel, Completions.ServiceConfig}
  alias Oli.Repo

  @topic "genai:configuration"

  @doc "The after-commit invalidation topic; nodes also periodically reload durable configuration."
  def topic, do: @topic

  @doc "Lists Providers without exposing their encrypted credentials in inspection."
  def providers, do: Repo.all(from p in Provider, order_by: p.id)

  @doc "Creates or updates a Provider and invalidates any old probe generation after commit."
  def save_provider(provider, attrs) do
    transaction(fn ->
      current =
        case provider.id do
          nil -> provider
          id -> lock_provider(id)
        end

      changeset = Provider.changeset(current, attrs)

      changeset =
        case current.id do
          nil -> changeset
          _ -> put_change(changeset, :config_version, current.config_version + 1)
        end

      saved = persist(changeset)
      designate_locked(saved.id)
      saved
    end)
  end

  @doc "Deletes an unreferenced Provider; model foreign keys protect configured connections."
  def delete_provider(provider) do
    transaction(fn ->
      current = lock_provider(provider.id)

      changeset =
        current
        |> change()
        |> foreign_key_constraint(:id, name: :registered_models_provider_id_fkey)

      case Repo.delete(changeset) do
        {:ok, deleted} -> deleted
        {:error, invalid} -> Repo.rollback(invalid)
      end
    end)
  end

  @doc "Persists a model and serializes designation with edits affecting either Provider."
  def save_model(model, attrs) do
    transaction(fn ->
      model =
        case model.id do
          nil -> model
          id -> Repo.get!(RegisteredModel, id)
        end

      attrs = Map.new(attrs, fn {key, value} -> {to_string(key), value} end)
      changeset = RegisteredModel.changeset(model, attrs)

      ids =
        [model.provider_id, get_field(changeset, :provider_id)]
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> Enum.sort()

      Enum.each(ids, &lock_provider/1)

      current =
        case model.id do
          nil -> model
          id -> Repo.get!(RegisteredModel, id)
        end

      # Rebuild from the locked current value so a stale form cannot restore flags
      # or membership that changed after it was opened.
      changeset = RegisteredModel.changeset(current, attrs)
      changeset = validate_required(changeset, [:provider_id])
      saved = persist(changeset)

      case (current.provider_id != saved.provider_id or current.capabilities != saved.capabilities) and
             not is_nil(current.provider_id) do
        true -> validate_model_dependencies!(saved.id)
        false -> :ok
      end

      Enum.each(ids, &designate_locked/1)
      Repo.get!(RegisteredModel, saved.id)
    end)
  end

  @doc "Deletes a model and deterministically designates a replacement probe model."
  def delete_model(model) do
    transaction(fn ->
      model = Repo.get!(RegisteredModel, model.id)

      case model.provider_id do
        nil -> :ok
        id -> lock_provider(id)
      end

      current = Repo.get!(RegisteredModel, model.id)

      changeset =
        Enum.reduce(
          [:primary_model_id, :secondary_model_id, :backup_model_id],
          change(current),
          fn field, cs ->
            foreign_key_constraint(cs, :id, name: "completions_service_configs_#{field}_fkey")
          end
        )

      deleted =
        case Repo.delete(changeset) do
          {:ok, deleted} -> deleted
          {:error, changeset} -> Repo.rollback(changeset)
        end

      case current.provider_id do
        nil -> :ok
        id -> designate_locked(id)
      end

      deleted
    end)
  end

  @doc "Saves ServiceConfig selections with Provider membership and capability validation."
  def save_service_config(config, attrs) do
    transaction(fn ->
      config =
        case config.id do
          nil -> config
          id -> Repo.get!(ServiceConfig, id)
        end

      changeset = ServiceConfig.changeset(config, attrs)
      models = models_for(changeset)

      models
      |> Enum.map(fn {_, model} -> model.provider_id end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.each(&lock_provider/1)

      changeset |> validate_selections(models_for(changeset)) |> persist()
    end)
  end

  @doc "Deletes an unused ServiceConfig in the same transactional invalidation boundary."
  def delete_service_config(config) do
    transaction(fn ->
      current = Repo.get!(ServiceConfig, config.id)

      changeset =
        current
        |> change()
        |> foreign_key_constraint(:id, name: :gen_ai_feature_configs_service_config_id_fkey)

      case Repo.delete(changeset) do
        {:ok, deleted} -> deleted
        {:error, invalid} -> Repo.rollback(invalid)
      end
    end)
  end

  @doc "Checks current tier relationships, including configurations awaiting post-migration repair."
  def audit_service_config(config) do
    changeset = ServiceConfig.changeset(config, %{})

    models =
      case Enum.all?(
             [config.primary_model, config.secondary_model, config.backup_model],
             &(not is_struct(&1, Ecto.Association.NotLoaded))
           ) do
        true ->
          for tier <- [:primary, :secondary, :backup],
              model = Map.get(config, association_field(tier)),
              not is_nil(model),
              into: %{},
              do: {tier, model}

        false ->
          models_for(changeset)
      end

    validate_selections(changeset, models)
  end

  @doc "Reconciles a Provider's lowest-ID flagged model, persisting a fallback flag if necessary."
  def reconcile_probe_model(provider_id) do
    Repo.transaction(fn ->
      configuration_lock()
      lock_provider(provider_id)
      designate_locked(provider_id)
    end)
  end

  @doc "Loads a consistent configuration snapshot; disabled checks never designate models on startup."
  def runtime_configuration(opts \\ []) do
    reconcile? = Keyword.get(opts, :reconcile_probes, true)

    {:ok, snapshot} =
      Repo.transaction(fn ->
        configuration_lock()
        # Read model selection and inference settings in one query.
        models =
          Repo.all(
            from m in RegisteredModel,
              order_by: m.id,
              select:
                struct(m, [
                  :id,
                  :provider_id,
                  :health_check,
                  :model,
                  :name,
                  :capabilities,
                  :timeout,
                  :recv_timeout
                ])
          )

        grouped = Enum.group_by(models, & &1.provider_id)

        {monitored, fallback_ids} =
          Enum.map_reduce(providers(), [], fn provider, fallbacks ->
            candidates = Map.get(grouped, provider.id, [])
            selected = Enum.find(candidates, & &1.health_check)

            case {selected, reconcile?, candidates} do
              {nil, true, [first | _]} ->
                {%{provider: provider, model: %{first | health_check: true}, models: candidates},
                 [first.id | fallbacks]}

              _ ->
                {%{provider: provider, model: selected, models: candidates}, fallbacks}
            end
          end)

        case fallback_ids do
          [] ->
            :ok

          ids ->
            Repo.update_all(from(m in RegisteredModel, where: m.id in ^ids),
              set: [health_check: true]
            )
        end

        by_id = Map.new(models, &{&1.id, &1})

        configs =
          Repo.all(ServiceConfig)
          |> Enum.map(fn config ->
            %{
              config
              | primary_model: by_id[config.primary_model_id],
                secondary_model: by_id[config.secondary_model_id],
                backup_model: by_id[config.backup_model_id]
            }
          end)

        issues =
          Enum.reduce(configs, %{}, fn config, issues ->
            tier_models =
              for tier <- [:primary, :secondary, :backup],
                  model = Map.get(config, association_field(tier)),
                  not is_nil(model),
                  into: %{},
                  do: {tier, model}

            changeset = validate_selections(ServiceConfig.changeset(config, %{}), tier_models)

            case changeset.valid? do
              true ->
                issues

              false ->
                Map.put(
                  issues,
                  config.id,
                  Enum.map(changeset.errors, fn {field, {message, _}} -> {field, message} end)
                )
            end
          end)

        %{providers: monitored, service_configs: configs, service_config_issues: issues}
      end)

    snapshot
  end

  @doc "Publishes a committed change. Polling remains necessary because PubSub is not durable."
  def broadcast_change do
    Phoenix.PubSub.broadcast(Oli.PubSub, @topic, :genai_configuration_changed)
  end

  defp transaction(fun) do
    nested? = Repo.in_transaction?()

    case Repo.transaction(fn ->
           configuration_lock()
           fun.()
         end) do
      {:ok, result} ->
        case nested? do
          true -> :ok
          false -> broadcast_change()
        end

        {:ok, result}

      {:error, _} = error ->
        error
    end
  end

  defp persist(changeset) do
    result =
      case changeset.data.__meta__.state do
        :built -> Repo.insert(changeset)
        _ -> Repo.update(changeset)
      end

    case result do
      {:ok, saved} -> saved
      {:error, invalid} -> Repo.rollback(invalid)
    end
  end

  defp configuration_lock, do: Repo.query!("SELECT pg_advisory_xact_lock(109492, 2)")

  defp lock_provider(id) do
    case Repo.one(from p in Provider, where: p.id == ^id, lock: "FOR UPDATE") do
      nil -> Repo.rollback(:provider_not_found)
      provider -> provider
    end
  end

  defp designate_locked(provider_id) do
    query = from m in RegisteredModel, where: m.provider_id == ^provider_id, order_by: m.id

    case Repo.one(from m in query, where: m.health_check == true, limit: 1) do
      nil ->
        case Repo.one(from m in query, limit: 1) do
          nil -> nil
          model -> Repo.update!(change(model, health_check: true))
        end

      model ->
        model
    end
  end

  defp models_for(changeset) do
    for tier <- [:primary, :secondary, :backup],
        id = get_field(changeset, model_field(tier)),
        not is_nil(id),
        model = Repo.get(RegisteredModel, id),
        not is_nil(model),
        into: %{},
        do: {tier, model}
  end

  defp validate_selections(changeset, models) do
    primary = models[:primary]

    Enum.reduce(models, changeset, fn {tier, model}, cs ->
      cs =
        case {primary, model.provider_id, tier} do
          {_, nil, _} ->
            add_error(cs, model_field(tier), "must belong to a configured Provider")

          {%{provider_id: main}, other, :secondary} when main != other ->
            add_error(cs, :secondary_model_id, "must belong to the primary Provider")

          {%{provider_id: main}, main, :backup} ->
            add_error(cs, :backup_model_id, "must belong to a different Provider")

          _ ->
            cs
        end

      required = get_field(cs, :required_capabilities) || []

      case Enum.all?(required, &(&1 in model.capabilities)) do
        true -> cs
        false -> add_error(cs, model_field(tier), "does not support the required capabilities")
      end
    end)
  end

  defp validate_model_dependencies!(model_id) do
    Repo.all(
      from c in ServiceConfig,
        where:
          c.primary_model_id == ^model_id or c.secondary_model_id == ^model_id or
            c.backup_model_id == ^model_id
    )
    |> Enum.each(fn config ->
      case audit_service_config(config) do
        %{valid?: true} -> :ok
        changeset -> Repo.rollback(changeset)
      end
    end)
  end

  defp association_field(:primary), do: :primary_model
  defp association_field(:secondary), do: :secondary_model
  defp association_field(:backup), do: :backup_model

  defp model_field(:primary), do: :primary_model_id
  defp model_field(:secondary), do: :secondary_model_id
  defp model_field(:backup), do: :backup_model_id
end
