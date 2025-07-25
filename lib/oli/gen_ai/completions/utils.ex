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
    |> safe_replace(":api_key", Map.get(params, "api_key", ""))
    |> safe_replace(":secondary_api_key",  Map.get(params, "secondary_api_key", ""))
  end

  defp safe_replace(str, match, value_or_nil) do
    case value_or_nil do
      nil -> str
      value -> String.replace(str, match, value)
    end
  end
end
