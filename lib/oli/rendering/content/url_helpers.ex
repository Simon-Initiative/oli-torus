defmodule Oli.Rendering.Content.UrlHelpers do
  @moduledoc """
  Shared URL helpers for rendered content links.
  """

  def append_query(path, nil), do: path
  def append_query(path, []), do: path

  def append_query(path, params) do
    params =
      params
      |> Enum.reject(fn {_key, value} -> is_nil(value) or value == "" end)
      |> Map.new()

    case map_size(params) do
      0 -> path
      _ -> "#{path}?#{URI.encode_query(params)}"
    end
  end
end
