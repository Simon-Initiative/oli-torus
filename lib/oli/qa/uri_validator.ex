defmodule Oli.Qa.UriValidator do
  @moduledoc """
  This module is used for validating remote resources given a map with a URI via a head request.

  It is currently set up just for QA reviews, but could be easily changed to add support for
  raw uris or maps with a uri value.

  This logic could be extended to validate mime types / etc rather than just fetching the resource.
  """

  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources.Revision

  @internal_link_prefix "/course/link/"

  # returns only valid uris
  def valid_uris(elements, project_slug) when is_list(elements) do
    elements
    |> validate_uris(project_slug)
    |> Map.get(:ok, [])
  end

  # returns only invalid uris
  def invalid_uris(elements, project_slug) when is_list(elements) do
    elements
    |> validate_uris(project_slug)
    |> Map.get(:error, [])
  end

  # returns all uris as a map of lists grouped by :ok (valid), :error (invalid)
  # elements are of type %{ id, content }
  def validate_uris(elements, project_slug) when is_list(elements) do
    IO.inspect elements
    verify_with_slug = fn e -> verify_link(e, project_slug) end

    elements
    |> Task.async_stream(verify_with_slug)
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

  defp verify_link(%{ content: content } = element, project_slug) do

    case get_uri(content) do
      @internal_link_prefix <> resource_slug -> verify_internal_link(element, resource_slug, project_slug)
      uri -> verify_external_link(element, uri)
    end

  end

  # we verify internal links by resolving the resource slug to see if
  # it actually resolves and that it resolves to a non-deleted revision
  defp verify_internal_link(element, resource_slug, project_slug) do
    case AuthoringResolver.from_revision_slug(project_slug, resource_slug) do
      nil -> {:error, element}
      %Revision{deleted: true} -> {:error, element}
      _ -> {:ok, element}
    end
  end

  defp verify_external_link(element, uri) do
    if !valid_uri?(uri)
    do {:error, element}
    else
      {:ok, element}
    end
  end

  def valid_uri?(uri) do
    try do
      uri = URI.parse(uri)
      uri.scheme != nil && uri.host =~ "."
    rescue
      _ -> false
    end
  end

  # async stream tasks emit {:ok, value} tuples upon successful completion
  defp extract_stream_result({:ok, value}), do: value

  defp get_status(tuple), do: elem(tuple, 0)
  defp get_value(tuple), do: elem(tuple, 1)

  defp get_uri(%{"href" => href}), do: href
  defp get_uri(%{"src" => src}), do: src
end
