defmodule Oli.Qa.UriValidator do
  @moduledoc """
  This module is used for validating remote resources given a map with a URI via a head request.

  It is currently set up just for QA reviews, but could be easily changed to add support for
  raw uris or maps with a uri value.
  """



  def validate_uris(link_reviews) when is_list(link_reviews) do
    results = link_reviews
    |> Task.async_stream(&fetch/1)
    |> Stream.map(fn {:ok, review} -> review end)
    |> Stream.filter(fn result ->
      case result do
        {:ok, review} -> false
        {:error, review} -> true
      end
    end)
    |> Stream.map(fn {_, review} -> review end)
    |> Enum.to_list()

    IO.inspect(results, label: "results")
  end

  defp fetch(link_review) do
    content = link_review.content
    case HTTPoison.head(get_uri(content)) do
      {:ok, _} -> {:ok, link_review}
      _ -> {:error, link_review}
    end
  end

  defp invalid?(%{ content: content } = _link_review) do
    case HTTPoison.head(get_uri(content)) do
      {:ok, _} -> false
      _ -> true
    end
  end

  defp get_uri(%{"href" => href}), do: href
  defp get_uri(%{"src" => src}), do: src
end
