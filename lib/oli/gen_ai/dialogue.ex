defmodule Oli.GenAI.Dialogue do
  require Logger

  @moduledoc """
  This module implements a statement dialogue between a user and a LLM model.

  The dialogue is guided by a `ServiceConfig` which contains the primary and
  backup models to use for the dialogue.  The dialogue is intended to be
  stateful - as each user message that is sent results in the return on an
  updated dialogue state.

  """

  alias Oli.GenAI.Completions.ServiceConfig
  alias Oli.GenAI.Completions.Message
  alias Oli.GenAI.Completions.Function
  alias Oli.GenAI.Completions.RegisteredModel
  alias Oli.GenAI.Completions

  defstruct [
    :service_config,
    :messages,
    :response_handler_fn,
    :functions,
    :registered_model
  ]

  def new(%ServiceConfig{} = service_config, messages, functions, dialogue_listener, options \\ []) do
    %__MODULE__{
      service_config: service_config,
      messages: messages,
      dialogue_listener: dialogue_listener,
      functions: functions,
      registered_model: service_config.primary_model
    }
  end

  def engage(
        %__MODULE__{
          registered_model: registered_model,
          messages: messages,
          functions: functions,
          dialogue_listener: dialogue_listener
        } =
          dialogue
      ) do

    response_handler_fn = fn response ->
      case response do
        {:finished} ->
          dialogue_listener.complete()

        {:delta, :function_call, function_call} ->

        {:delta, :content, content} ->
          dialogue_listener.tokens_received(content)
      end
    end

    Completions.stream(messages, functions, registered_model, response_handler_fn) do
      {:error, error} ->
        if should_retry?(dialogue) do
          dialogue
          |> fallback()
          |> engage()
        else
          {:error, error}
        end

      {:ok, _} ->
        {:ok, dialogue}
    end
  end

  defp should_retry?(dialogue) do
    dialogue.service_config.backup_model &&
      dialogue.service_config.backup_model != dialogue.registered_model
  end

  defp fallback(dialogue), do: Map.put(dialogue, :registered_model, dialogue.service_config.backup_model)

  def add_message(
        %__MODULE__{messages: messages} = dialog,
        message
      ) do
    Map.put(dialog, :messages, messages ++ [message])
  end

end
