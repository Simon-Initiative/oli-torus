defmodule OliWeb.Delivery.NewCourse.NameCourse do
  use OliWeb, :html

  attr(:changeset, :map, required: true)
  attr(:copy_source?, :boolean, default: false)
  attr(:copy_options, :map, default: %{})

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
          <.input
            label="Only online"
            field={@changeset[:class_modality]}
            value="online"
            type="custom_radio"
          />
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

      <fieldset :if={@copy_source?} class="flex flex-col gap-3">
        <legend class="font-semibold">Choose what to copy</legend>
        <p class="text-sm text-gray-600 dark:text-gray-300">
          Course content is always copied as an independent snapshot. Choose which instructor
          settings to carry into the new course.
        </p>

        <input type="hidden" name="copy_options[content]" value="true" />
        <label class="flex items-center gap-2">
          <input id="copy-course-content" type="checkbox" checked disabled /> Course content
        </label>

        <%= for {group, label} <- copy_option_labels() do %>
          <label class="flex items-center gap-2">
            <input
              id={"copy-#{String.replace(Atom.to_string(group), "_", "-")}"}
              type="checkbox"
              name={"copy_options[#{group}]"}
              value="true"
              checked={Map.get(@copy_options, group, true)}
            />
            {label}
          </label>
        <% end %>
      </fieldset>
    </.form>
    """
  end

  defp copy_option_labels do
    [
      schedule: "Schedule and gating rules",
      section_settings: "Course settings",
      assessment_settings: "Assessment settings",
      ai_settings: "AI settings"
    ]
  end
end
