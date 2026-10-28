defmodule Oli.GenAI.Operations do
  @moduledoc "Secret-free rollout audit and explicit credential preparation for legacy rollback."
  import Ecto.Query
  alias Oli.{GenAI, Repo}
  alias Oli.GenAI.{Configuration, Provider}
  alias Oli.GenAI.Completions.RegisteredModel

  @doc "Audits persisted relationships, legacy mapping and per-node allocations without making network requests."
  def audit do
    providers = Map.new(GenAI.providers(), &{&1.id, &1})
    models = GenAI.registered_models()
    configs = GenAI.service_configs()

    issues =
      for config <- configs, cs = Configuration.audit_service_config(config), not cs.valid? do
        %{service_config_id: config.id, fields: Enum.map(cs.errors, &elem(&1, 0)) |> Enum.uniq()}
      end

    model_issues =
      Enum.flat_map(models, fn model ->
        p = providers[model.provider_id]

        cond do
          is_nil(p) ->
            [%{model_id: model.id, category: :missing_provider}]

          model.provider != p.adapter ->
            [%{model_id: model.id, category: :adapter_mismatch}]

          p.adapter == :claude ->
            [%{model_id: model.id, category: :deferred_transport}]

          p.adapter == :open_ai and
              (model.url_template != p.base_url or model.api_key != p.api_key or
                 model.secondary_api_key != p.organization_key) ->
            [%{model_id: model.id, category: :legacy_connection_differs}]

          true ->
            []
        end
      end)

    allocations =
      for config <- configs,
          tier <- [:primary, :secondary, :backup],
          not is_nil(Map.get(config, String.to_existing_atom("#{tier}_model_id"))) do
        %{
          service_config_id: config.id,
          tier: tier,
          capacity: Map.fetch!(config, String.to_existing_atom("#{tier}_pool_capacity"))
        }
      end

    missing_keys =
      for {id, p} <- providers,
          p.adapter == :open_ai and (is_nil(p.api_key) or p.api_key == ""),
          do: id

    %{
      service_config_issues: issues,
      model_issues: model_issues,
      providers_missing_credentials: missing_keys,
      allocations_per_node: allocations,
      configured_connections_per_node: Enum.sum(Enum.map(allocations, & &1.capacity)),
      provider_count: map_size(providers),
      model_count: length(models)
    }
  end

  @doc "Explicitly synchronizes OpenAI legacy connection columns before deploying an older release. Does not print credentials."
  def prepare_legacy_rollback do
    Repo.transaction(fn ->
      Repo.query!("SELECT pg_advisory_xact_lock(109492, 2)")
      providers = Map.new(Repo.all(from p in Provider, lock: "FOR UPDATE"), &{&1.id, &1})
      models = Repo.all(from m in RegisteredModel, where: m.provider == :open_ai, order_by: m.id)

      Enum.each(models, fn model ->
        case providers[model.provider_id] do
          %Provider{adapter: :open_ai, api_key: key} = provider
          when is_binary(key) and byte_size(key) > 0 ->
            case Provider.origin(Provider.endpoint(provider, model)) do
              {:ok, _} -> :ok
              _ -> Repo.rollback(:invalid_legacy_connection)
            end

            model
            |> Ecto.Changeset.change(
              url_template: provider.base_url,
              api_key: key,
              secondary_api_key: provider.organization_key
            )
            |> Repo.update!()

          _ ->
            Repo.rollback(:invalid_legacy_connection)
        end
      end)

      length(models)
    end)
  end
end
