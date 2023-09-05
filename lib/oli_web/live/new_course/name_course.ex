defmodule OliWeb.Delivery.NewCourse.NameCourse do
  use OliWeb, :html

  attr(:changeset, :map, required: true)

  def render(assigns) do
    ~H"""
    <.form id="name-course-form" for={@changeset} class="flex flex-col gap-8 mt-8">
      <label class="flex flex-col">
        <span required for="course-name-field">Course name</span>
        <.input field={@changeset[:title]} />
      </label>

      <label class="flex flex-col">
        <span required for="course-section-number-field">Course section number</span>
        <.input field={@changeset[:course_section_number]} />
      </label>

      <div class="flex flex-col">
        <span required for="course-modality-field">My class meets...</span>

        <div class="flex flex-wrap gap-2">
          <.input
            label="Only in person"
            field={@changeset[:class_modality]}
            value="in_person"
            type="custom_radio"
          />
          <.input label="Only online" field={@changeset[:class_modality]} value="online" type="custom_radio" />
          <.input
            label="Both in person and online"
            field={@changeset[:class_modality]}
            value="hybrid"
            type="custom_radio"
          />
          <.input
            label="Never, it's a self paced course"
            field={@changeset[:class_modality]}
            value="never"
            type="custom_radio"
          />
        </div>
      </div>
    </.form>
    """
  end
end
