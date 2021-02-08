
defmodule Oli.HTTP do
  def http do
    case Application.fetch_env(:oli, :http_client) do
      {:ok, http_client} ->
        http_client
      :error ->
        HTTPoison
    end
  end
end
