defmodule Oli.GenAI.Completions do

  @moduledoc """
  This module provides a unified interface for chat completion from any registered
  LLM model and provider.  This is only a chat completion inferface. There
  is no state management and no automatic function calling, no automatic retry, etc.

  Synchronous and asynchronous chat completion are supported via the
  `generate` and `stream` functions.
  """

  alias Oli.GenAI.Completions.RegisteredModel

  def generate(messages, functions, %RegisteredModel{} = registered_model) do
    get_provider(registered_model)
    |> apply(:generate, [messages, functions, registered_model])
  end

  def stream(messages, functions, %RegisteredModel{} = registered_model, response_handler_fn) do
    get_provider(registered_model)
    |> apply(:stream, [messages, functions, registered_model, response_handler_fn])
  end

  defp get_provider(%RegisteredModel{} = registered_model) do
    case registered_model.provider do
      :null -> Oli.GenAI.Completions.NullProvider
      :open_ai -> Oli.GenAI.Completions.OpenAICompliantProvider
      :claude -> Oli.GenAI.Completions.ClaudeProvider
    end
  end

end
