defmodule Oli.GenAI.Completions.Function do

  @derive Jason.Encoder
  defstruct [
    :name,
    :description,
    :parameters
  ]

  def new(name, description, parameters) do
    %__MODULE__{
      name: name,
      description: description,
      parameters: parameters
    }
  end
end
