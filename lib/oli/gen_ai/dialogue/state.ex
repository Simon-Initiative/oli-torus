defmodule Oli.GenAI.Dialogue.State do
  alias Oli.GenAI.Dialogue.Configuration

  @moduledoc """
  The state of a dialogue session. This contains a snapshot of the dialogue
  configuration and within it the (initial) messages and the service config.

  It then also contains the active messages of this dialogue, the currently
  used registered model and information regarding "in flight" function calls.
  """

  @type t :: %__MODULE__{}

  defstruct [
    :configuration,
    :messages,
    :adaptive_runtime_message,
    :registered_model,
    :function_name,
    :function_args,
    :function_id,
    :function_message
  ]

  def new(%Configuration{messages: messages, service_config: service_config} = configuration) do
    {adaptive_runtime_messages, other_messages} =
      Enum.split_with(messages, &(&1.name == "adaptive_runtime_update"))

    %__MODULE__{
      configuration: configuration,
      # Keep newest messages at the head so appends/replacements stay O(1).
      messages: other_messages |> Enum.reverse(),
      adaptive_runtime_message: List.last(adaptive_runtime_messages),
      registered_model: service_config.primary_model,
      function_name: nil,
      function_args: nil,
      function_id: nil,
      function_message: nil
    }
  end
end
