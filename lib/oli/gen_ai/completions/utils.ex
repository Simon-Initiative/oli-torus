defmodule Oli.GenAI.Completions.Utils do

  def estimate_token_length(function) when is_map(function) do
    Jason.encode!(function)
    |> estimate_token_length()
  end

  def estimate_token_length(content) do
    String.length(content) |> div(4)
  end

  def realize_url(url_template, params) do
    url_template
    |> String.replace(":model", params["model"])
    |> String.replace(":api_key", params["api_key"])
    |> String.replace(":secondary_api_key", params["secondary_api_key"])
  end
end
