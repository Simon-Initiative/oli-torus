defmodule Oli.GenAI.Administrative do
  @moduledoc "Explicit bounded diagnostic requests; callers authorize administrators before invoking this API."
  alias Oli.GenAI.{Execution, PoolManager, RoutingPlan, Runtime}
  alias Oli.GenAI.Completions.{RegisteredModel, ServiceConfig}

  @doc "Uses production routing with a ServiceConfig, otherwise a dedicated administrative pool. Never changes health."
  def generate(messages, functions, %RegisteredModel{} = model, opts \\ []) do
    runtime = Keyword.get(opts, :runtime, Runtime)
    execution_opts = Keyword.take(opts, [:total_timeout_ms, :provider_opts])

    case Keyword.get(opts, :service_config) do
      %ServiceConfig{} = config ->
        Execution.generate(%{runtime: runtime}, messages, functions, config, execution_opts)

      nil ->
        with {:ok, inputs} <- Runtime.administrative_configuration(model.id, runtime),
             {:ok, plan} <- plan(inputs) do
          Execution.generate_in_plan(messages, functions, plan, execution_opts)
        end
    end
  catch
    :exit, _ -> {:error, :configuration_unavailable}
  end

  defp plan(%{provider: %{enabled: false}}), do: {:error, :provider_ineligible}

  defp plan(%{model: %{provider: :null} = model}),
    do: {:ok, %RoutingPlan{selected_model: model, tier: :administrative, reason: :administrative}}

  defp plan(
         %{
           provider: %{adapter: :open_ai, api_key: key} = provider,
           model: %{provider: :open_ai} = model
         } = inputs
       )
       when is_binary(key) and byte_size(key) > 0 do
    with {:ok, key} <- PoolManager.administrative_key(provider, model),
         {:ok, pool} <- PoolManager.lookup(inputs.pool_manager, key) do
      {:ok,
       %RoutingPlan{
         selected_model: model,
         provider: provider,
         pool: pool,
         signature: provider.config_version,
         tier: :administrative,
         reason: :administrative,
         request_type: :generate
       }}
    end
  end

  defp plan(_), do: {:error, :unsupported_administrative_transport}
end
