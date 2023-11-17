defmodule Oli.Conversation.Model do

  @default_model :fast

  def default(), do: @default_model

  def model(:fast), do: "gpt-3.5-turbo"
  def model(:large_context), do: "gpt-4"
  def model(:largest_context), do: "gpt-4-1106-preview"

  def token_limit("gpt-3.5-turbo"), do: 4096
  def token_limit("gpt-4"), do: 8192
  def token_limit("gpt-4-1106-preview"), do: 128000

  def token_limit(atom) when is_atom(atom) do
    model(atom)
    |> token_limit()
  end

end
