defmodule Oli.Conversation.Message do
  import Oli.Conversation.Common

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
