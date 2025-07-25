defmodule Oli.GenAI.Dialogue.Configuration do
  @moduledoc """
  The static configuration for a dialogue session.
  """

  @type t :: %__MODULE__{}

  defstruct [
    :service_config,
    :messages,
    :functions,
    :reply_to_pid
  ]

  def new(service_config, messages, functions, reply_to_pid) do
    %__MODULE__{
      service_config: service_config,
      messages: messages,
      functions: functions,
      reply_to_pid: reply_to_pid
    }
  end
end
