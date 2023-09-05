defmodule OliWeb.Delivery.NewCourse.CourseDetails do
  use OliWeb, :html

  @days [
    {:sunday, "Sun"},
    {:monday, "Mon"},
    {:tuesday, "Tue"},
    {:wednesday, "Wed"},
    {:thursday, "Thu"},
    {:friday, "Fri"},
    {:saturday, "Sat"}
  ]

  attr(:changeset, :map, required: true)

  def render(assigns) do
    assigns =
      assign(
        assigns,
        %{
          class_days: assigns.changeset[:class_days].value,
          class_modality: assigns.changeset[:class_modality].value,
          days: @days
        }
      )

    ~H"""
    <.form id="course-details-form" class="w-full" for={@changeset}>
      <div class="flex flex-col gap-8">
        <%= if @class_modality != :never do %>
          <div class="flex flex-col gap-1 flex-1">
            <span required>Days of the week you meet</span>
            <div class="flex flex-wrap gap-2">
              <%= for {value, label} <- @days do %>
                <.input
                  type="custom_checkbox"
                  field={@changeset[:class_days]}
                  value={value}
                  label={label}
                />
              <% end %>
            </div>
            <small class="torus-small mt-1">
              <i class="fa fa-circle-info mr-1" />
              This will allow for accurate action recommendations for you and your students to be accurate according to your meeting schedule
            </small>
          </div>
        <% end %>

        <div class="flex flex-col gap-2">
          <div class="flex gap-4 w-full">
            <div class="flex flex-col gap-1 flex-1">
              <span required>Course start date</span>
              <.input type="datetime-local" field={@changeset[:start_date]} />
            </div>
            <div class="flex flex-col gap-1 flex-1">
              <span required>Course end date</span>
              <.input type="datetime-local" field={@changeset[:end_date]} />
            </div>
          </div>
          <small class="torus-small mt-1">
            <i class="fa fa-circle-info mr-1" />
            The start and end dates help us recommend a teaching schedule and assignment cadence
          </small>
        </div>
      </div>
    </.form>
    """
  end
end
