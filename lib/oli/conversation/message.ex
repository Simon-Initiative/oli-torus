defmodule Oli.Conversation.Message do
  @derive Jason.Encoder
  defstruct [
    :role,
    :content,
    :name
  ]

  def new(role, content) do
    %__MODULE__{
      role: role,
      content: content
    }
  end

  def new(role, content, name) do
    %__MODULE__{
      role: role,
      content: content,
      name: name
    }
  end
end
