defmodule OliWeb.Delivery.Instructor.PreviewReturn do
  use OliWeb, :verified_routes

  @moduledoc """
  Resolves the instructor preview return context from a `return_to` URL.

  This module owns the preview-shell contract for:

  - validating that `return_to` stays within the current section
  - mapping safe paths to one of the supported instructor entry points
  - falling back to Customize Content when the path is missing or unsupported

  Supported origins are Customize Content, Assessment Settings, and Overview.
  """

  @preview_return_origins [
    %{key: :customize_content, label: "Return to Customize Content"},
    %{key: :assessment_settings, label: "Return to Assessment Settings"},
    %{key: :overview, label: "Return to Overview"}
  ]

  def resolve(section_slug, return_to) do
    safe_path = sanitize_return_to(return_to, section_slug)
    origin = infer_origin(safe_path, section_slug)

    %{
      label: label_for(origin),
      path: safe_path
    }
  end

  def sanitize_return_to("/" <> _ = path, section_slug) do
    prefix = "/sections/#{section_slug}"
    product_remix_prefix = "/authoring/products/#{section_slug}/remix"

    cond do
      String.starts_with?(path, "//") -> fallback_path(section_slug)
      safe_path_prefix?(path, prefix) -> path
      safe_path_prefix?(path, product_remix_prefix) -> path
      workspace_product_remix_path?(path, section_slug) -> path
      true -> fallback_path(section_slug)
    end
  end

  def sanitize_return_to(_path, section_slug), do: fallback_path(section_slug)

  def fallback_context(section_slug), do: resolve(section_slug, fallback_path(section_slug))

  def fallback_path(section_slug), do: ~p"/sections/#{section_slug}/remix"

  defp safe_path_prefix?(path, prefix) do
    path == prefix or String.starts_with?(path, prefix <> "/") or
      String.starts_with?(path, prefix <> "?")
  end

  defp workspace_product_remix_path?(path, section_slug) do
    case URI.parse(path) do
      %URI{scheme: nil, host: nil, path: parsed_path} when is_binary(parsed_path) ->
        case String.split(parsed_path, "/", trim: true) do
          ["workspaces", "course_author", _project_slug, "products", ^section_slug, "remix"] ->
            true

          ["workspaces", "course_author", _project_slug, "products", ^section_slug, "remix" | _] ->
            true

          _ ->
            false
        end

      _ ->
        false
    end
  end

  defp infer_origin(path, section_slug) do
    path = URI.parse(path).path || ""

    cond do
      customize_content_return_path?(path, section_slug) -> :customize_content
      assessment_settings_return_path?(path, section_slug) -> :assessment_settings
      overview_return_path?(path, section_slug) -> :overview
      true -> :customize_content
    end
  end

  defp label_for(origin) do
    Enum.find_value(@preview_return_origins, "Return to Customize Content", fn
      %{key: ^origin, label: label} -> label
      _ -> nil
    end)
  end

  defp customize_content_return_path?(path, section_slug) do
    base_path = "/sections/#{section_slug}/remix"
    product_base_path = "/authoring/products/#{section_slug}/remix"

    path == base_path or String.starts_with?(path, base_path <> "/") or
      path == product_base_path or String.starts_with?(path, product_base_path <> "/") or
      workspace_product_remix_path?(path, section_slug)
  end

  defp assessment_settings_return_path?(path, section_slug) do
    settings_base_path = "/sections/#{section_slug}/assessment_settings/settings"

    student_exceptions_base_path =
      "/sections/#{section_slug}/assessment_settings/student_exceptions"

    path == settings_base_path <> "/all" or
      path == student_exceptions_base_path <> "/all" or
      String.starts_with?(path, settings_base_path <> "/") or
      String.starts_with?(path, student_exceptions_base_path <> "/")
  end

  defp overview_return_path?(path, section_slug) do
    base_path = "/sections/#{section_slug}"

    path == base_path or
      String.starts_with?(path, base_path <> "/instructor_dashboard/overview") or
      String.starts_with?(path, base_path <> "/instructor_dashboard/preview/overview")
  end
end
