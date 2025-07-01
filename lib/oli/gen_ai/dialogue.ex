defmodule Oli.GenAI.Dialogue do
  require Logger

  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.Completions.Function
  alias Oli.GenAI.Completions.RegisteredModel

  defstruct [
    :service_config,
    :rendered_messages,
    :messages,
    :response_handler_fn,
    :functions,
    :registered_model
  ]

  def new(%ServiceConfig{} = service_config, messages, functions, response_handler_fn, options \\ []) do
    %__MODULE__{
      service_config: service_config,
      rendered_messages: [],
      messages: messages,
      response_handler_fn: response_handler_fn,
      functions: function,
      registered_model: service_config.primary_model
    }
  end

  def engage(
        %__MODULE__{
          registered_model: registered_model,
          messages: messages,
          rendered_messages: rendered_messages,
          response_handler_fn: response_handler_fn
        } =
          dialogue,
        message
      ) do

    case get_provider(registered_model)
    |> apply(:stream, [messages, functions, registered_model, response_handler_fn]) do
      {:error, error} ->
        if should_retry?(dialogue) do
          fallback(dialogue)
          |> engage(message)
        else
          {:error, error}
        end

      success ->
        success
    end

    add_message(dialogue, message)
  end

  defp should_retry?(dialogue) do
    dialogue.service_config.backup_model &&
      dialogue.service_config.backup_model != dialogue.registered_model
  end

  defp fallback(dialogue), do: Map.put(dialogue, :registered_model, dialogue.service_config.backup_model)

  defp get_provider(%RegisteredModel{} = registered_model) do
    case registered_model.provider do
      :open_ai -> Oli.GenAI.Completions.OpenAIProvider
      :gemini -> Oli.GenAI.Completions.GeminiProvider
      :claude -> Oli.GenAI.Completions.ClaudeProvider
    end
  end

  defp add_message(
        %__MODULE__{messages: messages, rendered_messages: rendered_messages} = dialog,
        message
      ) do
    Map.put(dialog, :messages, messages ++ [message])
    |> Map.put(:rendered_messages, rendered_messages ++ [message])
  end

end
