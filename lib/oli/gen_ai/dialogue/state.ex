defmodule Oli.GenAI.Dialogue.State do

  alias Oli.GenAI.Dialogue.Configuration

  @type t :: %__MODULE__{}

  defstruct [
    :configuration,
    :messages,
    :registered_model,
    :pending_function_name,
    :pending_function_args,
    :pending_function_message
  ]

  def new(%Configuration{messages: messages, service_config: service_config} = configuration) do
    %__MODULE__{
      configuration: configuration,
      messages: messages,
      registered_model: service_config.primary_model,
      pending_function_name: nil,
      pending_function_args: nil,
      pending_function_message: nil
    }
  end

end
