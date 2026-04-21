defmodule Oli.GenAI.Completions.Message do
  import Oli.GenAI.Completions.Utils

  @derive Jason.Encoder
  defstruct [
    :role,
    :content,
    :token_length,
    # name, id and input are used in function tool calling
    :name,
    :id,
    :input,
    :llm_provider_type,
    :llm_provider_url,
    :llm_model
  ]

  def new(role, content) do
    %__MODULE__{
      role: role,
      content: content,
      name: nil,
      token_length: estimate_token_length(content),
      id: nil,
      input: nil,
      llm_provider_type: nil,
      llm_provider_url: nil,
      llm_model: nil
    }
  end

  def new(role, content, name) do
    %__MODULE__{
      role: role,
      content: content,
      name: name,
      token_length: estimate_token_length(content),
      id: nil,
      input: nil,
      llm_provider_type: nil,
      llm_provider_url: nil,
      llm_model: nil
    }
  end
end
