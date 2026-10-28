defmodule Oli.GenAI.Completions do
  @moduledoc """
  This module provides a unified interface for chat completion from any registered
  LLM model and provider.  This is only a chat completion inferface. There
  is no state management and no automatic function calling, no automatic retry, etc.

  Synchronous and asynchronous chat completion are supported via the
  `generate` and `stream` functions.
  """

  alias Oli.GenAI.Completions.{ManagedOpenAI, RegisteredModel}

  @doc "Generates a completion, using explicit selected transport context when supplied."
  def generate(messages, functions, %RegisteredModel{} = registered_model, opts \\ []) do
    case Keyword.get(opts, :transport_context) do
      %{provider: provider} = plan when not is_nil(provider) ->
        ManagedOpenAI.request(:generate, messages, functions, plan, nil, opts)

      _ ->
        apply(get_provider(registered_model), :generate, [
          messages,
          functions,
          registered_model,
          opts
        ])
    end
  end

  @doc "Streams a completion through explicit transport context, retaining legacy adapter dispatch otherwise."
  def stream(
        messages,
        functions,
        %RegisteredModel{} = registered_model,
        response_handler_fn,
        opts \\ []
      ) do
    case Keyword.get(opts, :transport_context) do
      %{provider: provider} = plan when not is_nil(provider) ->
        ManagedOpenAI.request(:stream, messages, functions, plan, response_handler_fn, opts)

      _ ->
        apply(get_provider(registered_model), :stream, [
          messages,
          functions,
          registered_model,
          response_handler_fn
        ])
    end
  end

  def validate_registered_model(%RegisteredModel{provider: :null}), do: :ok

  def validate_registered_model(%RegisteredModel{api_key: api_key})
      when is_binary(api_key) and byte_size(api_key) > 0,
      do: :ok

  def validate_registered_model(%RegisteredModel{}),
    do: {:error, {:invalid_model_configuration, :missing_api_key}}

  defp get_provider(%RegisteredModel{} = registered_model) do
    case registered_model.provider do
      :null -> Oli.GenAI.Completions.NullProvider
      :open_ai -> Oli.GenAI.Completions.OpenAICompliantProvider
      :claude -> Oli.GenAI.Completions.ClaudeProvider
    end
  end
end
