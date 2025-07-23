defmodule Oli.GenAI.Completions.Message do
  import Oli.GenAI.Completions.Utils

  @derive Jason.Encoder
  defstruct [
    :role,
    :content,
    :name,
    :token_length
  ]

  def new(role, content) do
    %__MODULE__{
      role: role,
      content: content,
      name: nil,
      token_length: estimate_token_length(content)
    }
  end

  def new(role, content, name) do
    %__MODULE__{
      role: role,
      content: content,
      name: name,
      token_length: estimate_token_length(content)
    }
  end
end
