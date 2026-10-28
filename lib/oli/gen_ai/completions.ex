defmodule Oli.GenAI.Completions do
  @moduledoc """
  This module provides a unified interface for chat completion from any registered
  LLM model and provider.  This is only a chat completion inferface. There
  is no state management and no automatic function calling, no automatic retry, etc.

  Synchronous and asynchronous chat completion are supported via the
  `generate` and `stream` functions.
  """

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{} = registered_model, opts \\ []) do
    get_provider(registered_model)
    |> apply(:generate, [messages, functions, registered_model, opts])
  end

  def stream(messages, functions, %RegisteredModel{} = registered_model, response_handler_fn) do
    get_provider(registered_model)
    |> apply(:stream, [messages, functions, registered_model, response_handler_fn])
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
