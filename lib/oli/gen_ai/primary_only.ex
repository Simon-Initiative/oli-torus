defmodule Oli.GenAI.PrimaryOnly do
  @moduledoc "Emergency primary-only routing independent of health, routing caches and tier reconciliation."
  import Ecto.Query
  require Logger
  alias Oli.GenAI.{PoolManager, Provider, RoutingPlan}
  alias Oli.GenAI.Completions.ServiceConfig

  @doc "Starts an independent pool manager outside the normal routing supervisor."
  def start_link(opts) do
    case enabled?() do
      true ->
        Logger.warning(
          "GenAI primary-only routing enabled; secondary and backup routing disabled"
        )

      false ->
        :ok
    end

    PoolManager.start_link(Keyword.merge([name: __MODULE__, namespace: :primary_only], opts))
  end

  @doc false
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}

  @doc "Returns the node's effective emergency routing override."
  def enabled?, do: Application.get_env(:oli, :genai_routing_primary_only, false)

  @doc "Reads only the current primary and Provider from the database, retaining native capacity limits."
  def route(config_id, request_type) do
    configuration =
      Oli.Repo.one(
        from c in ServiceConfig,
          join: m in assoc(c, :primary_model),
          join: p in assoc(m, :configured_provider),
          where: c.id == ^config_id,
          select: {m, p, c.primary_pool_capacity}
      )

    case configuration do
      {_, %{enabled: false}, _} ->
        {:error, :provider_ineligible}

      {model, provider, capacity} ->
        plan = %RoutingPlan{
          selected_model: model,
          provider: provider,
          service_config_id: config_id,
          tier: :primary,
          reason: :kill_switch_primary_only,
          request_type: request_type
        }

        transport(plan, capacity)

      nil ->
        {:error, :invalid_configuration}
    end
  catch
    :exit, _ -> {:error, :pool_unavailable}
  end

  defp transport(%{provider: %{adapter: :null}} = plan, _capacity), do: {:ok, plan}

  defp transport(%{provider: %{adapter: :open_ai, api_key: key}} = plan, capacity)
       when is_binary(key) and byte_size(key) > 0 do
    plan = %{plan | signature: Provider.transport_signature(plan.provider, plan.selected_model)}

    with {:ok, origin} <- Provider.origin(Provider.endpoint(plan.provider, plan.selected_model)),
         {:ok, pool} <-
           PoolManager.ensure_pool(__MODULE__, {plan.service_config_id, :primary}, %{
             origin: origin,
             capacity: capacity,
             signature: plan.signature
           }) do
      {:ok, %{plan | pool: pool}}
    end
  end

  defp transport(_, _), do: {:error, :provider_ineligible}
end
