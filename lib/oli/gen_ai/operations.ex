defmodule Oli.GenAI.Operations do
  @moduledoc "Secret-free audit of Provider configuration and per-node allocations."
  alias Oli.GenAI
  alias Oli.GenAI.Configuration

  @doc "Audits persisted Provider relationships and per-node allocations without making network requests."
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

          p.adapter == :claude ->
            [%{model_id: model.id, category: :deferred_transport}]

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
end
