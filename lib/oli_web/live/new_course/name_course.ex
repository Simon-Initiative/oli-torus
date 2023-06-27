defmodule OliWeb.Delivery.NewCourse.NameCourse do
  use Phoenix.Component
  import Phoenix.HTML.Form

  alias OliWeb.Common.RadioButton

  attr :changeset, :map, required: true

  def render(assigns) do
    ~H"""
      <.form id="name-course-form" let={f} for={@changeset} class="flex flex-col gap-8 mt-8">
        <label class="flex flex-col">
          <span required for="course-name-field">Course name</span>
          <%= text_input f, :title, class: "torus-input" %>
        </label>

        <label class="flex flex-col">
          <span required for="course-section-number-field">Course section number</span>
          <%= text_input f, :course_section_number, class: "torus-input" %>
        </label>

        <div class="flex flex-col">
          <span required for="course-modality-field">My class meets...</span>

          <div class="flex flex-wrap gap-2" onclick="(e) => e.stopPropagation()">
            <RadioButton.item form={f} field={:class_modality} value="in_person" label="Only in person" />
            <RadioButton.item form={f} field={:class_modality} value="online" label="Only online" />
            <RadioButton.item form={f} field={:class_modality} value="hybrid" label="Both in person and online" />
            <RadioButton.item form={f} field={:class_modality} value="never" label="Never, it's a self paced course" />
          </div>
        </div>
      </.form>
    """
  end
end
