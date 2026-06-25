defmodule OliWeb.Delivery.Instructor.PreviewMode do
  @moduledoc """
  Small predicates for the instructor preview shell.

  Student section preview and instructor preview currently share several `/sections/:slug/preview`
  routes. The distinguishing signal for the instructor preview shell is the presence of an
  `instructor_preview_return` context, derived from a safe `return_to` URL. Plain student section
  preview has `preview_mode: true` without that return context.
  """

  def preview_mode?(%{assigns: assigns}), do: preview_mode?(assigns)

  def preview_mode?(assigns) when is_map(assigns), do: Map.get(assigns, :preview_mode) == true

  def preview_mode?(_), do: false

  def instructor_preview?(%{assigns: assigns}), do: instructor_preview?(assigns)

  def instructor_preview?(assigns) when is_map(assigns) do
    preview_mode?(assigns) and
      assigns
      |> Map.get(:instructor_preview_return)
      |> return_context?()
  end

  def instructor_preview?(_), do: false

  def student_section_preview?(%{assigns: assigns}), do: student_section_preview?(assigns)

  def student_section_preview?(assigns) when is_map(assigns),
    do: preview_mode?(assigns) and not instructor_preview?(assigns)

  def student_section_preview?(_), do: false

  defp return_context?(%{path: path}) when is_binary(path) and path != "", do: true
  defp return_context?(_), do: false
end
