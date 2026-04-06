defmodule OliWeb.Products.ImagePreviewState do
  alias Phoenix.Component

  @default_context :student_welcome

  def default_context, do: @default_context

  def select_context(socket, context) do
    Component.assign(socket, image_preview_selected_context: parse_context(context))
  end

  def open_modal(socket, %{"context" => context} = params) do
    case Map.get(params, "key") do
      nil -> open_modal(socket, context)
      "Enter" -> open_modal(socket, context)
      " " -> open_modal(socket, context)
      "Space" -> open_modal(socket, context)
      "Spacebar" -> open_modal(socket, context)
      _ -> socket
    end
  end

  def open_modal(socket, context) do
    Component.assign(socket,
      image_preview_selected_context: parse_context(context),
      image_preview_modal_open: true
    )
  end

  def close_modal(socket) do
    Component.assign(socket, image_preview_modal_open: false)
  end

  def show_next(socket) do
    Component.assign(socket,
      image_preview_selected_context: next_context(socket.assigns.image_preview_selected_context)
    )
  end

  def show_previous(socket) do
    Component.assign(socket,
      image_preview_selected_context:
        previous_context(socket.assigns.image_preview_selected_context)
    )
  end

  def parse_context("student_welcome"), do: :student_welcome
  def parse_context("my_course"), do: :my_course
  def parse_context("course_picker"), do: :course_picker
  def parse_context(:student_welcome), do: :student_welcome
  def parse_context(:my_course), do: :my_course
  def parse_context(:course_picker), do: :course_picker
  def parse_context(_), do: @default_context

  def next_context(:student_welcome), do: :my_course
  def next_context(:my_course), do: :course_picker
  def next_context(:course_picker), do: :course_picker
  def next_context(_), do: @default_context

  def previous_context(:student_welcome), do: :student_welcome
  def previous_context(:my_course), do: :student_welcome
  def previous_context(:course_picker), do: :my_course
  def previous_context(_), do: @default_context
end
