defmodule OliWeb.Delivery.Instructor.PreviewMode do
  alias OliWeb.Delivery.Instructor.PreviewReturn

  @moduledoc """
  Small predicates for the instructor preview shell.

  Student section preview and instructor preview are both instructor-facing preview tools, and they
  currently share several `/sections/:slug/preview` shell routes. Student section preview keeps
  course-level preview navigation but opens pages through normal delivery lesson routes. Instructor
  section preview opens pages through preview routes for the customization preview shell.

  Where available, `section_preview_kind` is the explicit signal for which kind of preview is
  active. Instructor preview also carries an `instructor_preview_return` context, derived from a
  safe `return_to` URL, which is used by the banner return target. The client-controlled
  `section_preview_kind` value is only honored as instructor preview when the `return_to` value can
  be validated for the current section.
  """

  @student_section_preview_kind "student"
  @instructor_section_preview_kind "instructor"

  def student_section_preview_kind, do: @student_section_preview_kind
  def instructor_section_preview_kind, do: @instructor_section_preview_kind

  def preview_mode?(%{assigns: assigns}), do: preview_mode?(assigns)

  def preview_mode?(assigns) when is_map(assigns), do: Map.get(assigns, :preview_mode) == true

  def preview_mode?(_), do: false

  def instructor_preview?(%{assigns: assigns}), do: instructor_preview?(assigns)

  def instructor_preview?(assigns) when is_map(assigns) do
    preview_mode?(assigns) and
      case Map.get(assigns, :section_preview_kind) do
        kind when kind in [:instructor, "instructor"] ->
          assigns
          |> Map.get(:instructor_preview_return)
          |> return_context?()

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

  def section_preview_kind(true, params) when is_map(params) do
    case Map.get(params, :section_preview_kind, Map.get(params, "section_preview_kind")) do
      kind when kind in [:instructor, @instructor_section_preview_kind] ->
        if safe_return_to_param?(params), do: :instructor, else: :student

      kind when kind in [:student, @student_section_preview_kind] ->
        :student

      _ ->
        if safe_return_to_param?(params), do: :instructor, else: :student
    end
  end

  def section_preview_kind(_preview_mode, _params), do: nil

  defp return_context?(%{path: path}) when is_binary(path) and path != "", do: true
  defp return_context?(_), do: false

  defp safe_return_to_param?(params) do
    section_slug = Map.get(params, :section_slug, Map.get(params, "section_slug"))
    return_to = Map.get(params, :return_to, Map.get(params, "return_to"))

    is_binary(section_slug) and is_binary(return_to) and return_to != "" and
      PreviewReturn.sanitize_return_to(return_to, section_slug) == return_to
  end
end
