defmodule Oli.GenAI.Completions do
  @moduledoc "Completion execution using an explicitly selected Provider and transport."

  alias Oli.GenAI.{Provider, RoutingPlan}
  alias Oli.GenAI.Completions.{ManagedOpenAI, NullProvider, RegisteredModel}

  @doc "Generates a completion through the selected Provider transport."
  def generate(messages, functions, %RegisteredModel{} = model, opts \\ []) do
    request(:generate, messages, functions, model, nil, opts)
  end

  @doc "Streams a completion through the selected Provider transport."
  def stream(messages, functions, %RegisteredModel{} = model, handler, opts \\ []) do
    request(:stream, messages, functions, model, handler, opts)
  end

  defp request(mode, messages, functions, model, handler, opts) do
    case Keyword.get(opts, :transport_context) do
      %RoutingPlan{provider: %Provider{enabled: false}} ->
        {:error, :provider_ineligible}

      %RoutingPlan{provider: %Provider{adapter: :null}, selected_model: ^model} ->
        case mode do
          :generate -> NullProvider.generate(messages, functions, model, opts)
          :stream -> NullProvider.stream(messages, functions, model, handler)
        end

      %RoutingPlan{provider: %Provider{adapter: :open_ai}, selected_model: ^model, pool: pool} =
          plan
      when is_pid(pool) ->
        ManagedOpenAI.request(mode, messages, functions, plan, handler, opts)

      %RoutingPlan{provider: %Provider{adapter: adapter}} when adapter != :open_ai ->
        {:error, :unsupported_adapter}

      _ ->
        {:error, :missing_transport_context}
    end
  end
end
