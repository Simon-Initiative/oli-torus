defmodule Oli.Qa.UriValidator do
  @moduledoc """
  This module is used for validating remote resources given a map with a URI via a head request.

  It is currently set up just for QA reviews, but could be easily changed to add support for
  raw uris or maps with a uri value.

  This logic could be extended to validate mime types / etc rather than just fetching the resource.
  """

  # returns only valid uris
  def valid_uris(elements) when is_list(elements) do
    elements
    |> validate_uris
    |> Map.get(:ok, [])
  end

  # returns only invalid uris
  def invalid_uris(elements) when is_list(elements) do
    elements
    |> validate_uris
    |> Map.get(:error, [])
  end

  # returns all uris as a map of lists grouped by :ok (valid), :error (invalid)
  # elements are of type %{ id, content }
  def validate_uris(elements) when is_list(elements) do
    elements
    |> Task.async_stream(&fetch/1)
    |> Stream.map(&extract_stream_result/1)
    |> Stream.map(&prettified_type/1)
    |> Enum.group_by(&get_status/1, &get_value/1)
  end

  defp prettified_type({status, value}) do
    type = case Map.get(value, :type) do
      "img" -> "image"
      "href" -> "link"
      _ -> "remote resource"
    end

    {status, Map.put(value, :prettified_type, type)}
  end

  defp fetch(%{ content: content } = element) do
    result = content
    |> get_uri
    |> HTTPoison.head

    case result do
      {:ok, _} -> {:ok, element}
      _ -> {:error, element}
    end
  end

  # async stream tasks emit {:ok, value} tuples upon successful completion
  defp extract_stream_result({:ok, value}), do: value

  defp get_status(tuple), do: elem(tuple, 0)
  defp get_value(tuple), do: elem(tuple, 1)

  defp get_uri(%{"href" => href}), do: href
  defp get_uri(%{"src" => src}), do: src
end
