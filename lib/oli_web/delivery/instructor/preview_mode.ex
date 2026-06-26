defmodule OliWeb.Delivery.Instructor.PreviewMode do
  @moduledoc """
  Small predicates for the instructor preview shell.

  Student section preview and instructor preview currently share several `/sections/:slug/preview`
  shell routes. Where available, `section_preview_kind` is the explicit signal for which kind of
  preview is active. Instructor preview also carries an `instructor_preview_return` context,
  derived from a safe `return_to` URL, which is used by the banner return target and as a fallback
  signal when `section_preview_kind` is absent.
  """

  def preview_mode?(%{assigns: assigns}), do: preview_mode?(assigns)

  def preview_mode?(assigns) when is_map(assigns), do: Map.get(assigns, :preview_mode) == true

  def preview_mode?(_), do: false

  def instructor_preview?(%{assigns: assigns}), do: instructor_preview?(assigns)

  def instructor_preview?(assigns) when is_map(assigns) do
    preview_mode?(assigns) and
      case Map.get(assigns, :section_preview_kind) do
        kind when kind in [:instructor, "instructor"] ->
          true

        kind when kind in [:student, "student"] ->
          false

        _ ->
          assigns
          |> Map.get(:instructor_preview_return)
          |> return_context?()
      end
  end

  def instructor_preview?(_), do: false

  def student_section_preview?(%{assigns: assigns}), do: student_section_preview?(assigns)

  def student_section_preview?(assigns) when is_map(assigns),
    do: preview_mode?(assigns) and not instructor_preview?(assigns)

  def student_section_preview?(_), do: false

  defp return_context?(%{path: path}) when is_binary(path) and path != "", do: true
  defp return_context?(_), do: false
end
