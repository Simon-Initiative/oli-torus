defmodule Oli.OpenAIClient do
  @callback embeddings(params :: list, config :: %OpenAI.Config{}) :: {:ok, map} | {:error, any}

  def embeddings(params, config), do: impl().embeddings(params, config)

  defp impl(), do: Application.get_env(:oli, :openai_client, OpenAI)
end
