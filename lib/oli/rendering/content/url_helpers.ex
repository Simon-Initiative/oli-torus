defmodule Oli.Rendering.Content.UrlHelpers do
  @moduledoc """
  Shared URL helpers for rendered content links.
  """

  def preview_lesson_path(section_slug, revision_slug, params \\ nil) do
    section_slug = encode_path_segment(section_slug)
    revision_slug = encode_path_segment(revision_slug)

    append_query("/sections/#{section_slug}/preview/lesson/#{revision_slug}", params)
  end

  def preview_selection_path(section_slug, revision_slug, selection_id, params \\ nil) do
    section_slug = encode_path_segment(section_slug)
    revision_slug = encode_path_segment(revision_slug)
    selection_id = encode_path_segment(selection_id)

    append_query(
      "/sections/#{section_slug}/preview/lesson/#{revision_slug}/selection/#{selection_id}",
      params
    )
  end

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

  defp encode_path_segment(segment) do
    segment
    |> to_string()
    |> URI.encode(&path_segment_char?/1)
  end

  defp path_segment_char?(char)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char in [?-, ?., ?_, ?~],
       do: true

  defp path_segment_char?(_char), do: false
end
