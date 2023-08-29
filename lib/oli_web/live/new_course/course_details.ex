defmodule OliWeb.Delivery.NewCourse.CourseDetails do
  use Phoenix.Component

  alias OliWeb.Common.CustomCheckbox

  @days [
    {:sunday, "Sun"},
    {:monday, "Mon"},
    {:tuesday, "Tue"},
    {:wednesday, "Wed"},
    {:thursday, "Thu"},
    {:friday, "Fri"},
    {:saturday, "Sat"}
  ]

  attr :changeset, :map, required: true

  def render(assigns) do
    assigns =
      assign(
        assigns,
        %{
          class_days: Ecto.Changeset.fetch_field(assigns.changeset, :class_days) |> elem(1),
          class_modality:
            Ecto.Changeset.fetch_field(assigns.changeset, :class_modality) |> elem(1),
          days: @days
        }
      )

    ~H"""
    <.form :let={f} id="course-details-form" class="w-full" for={@changeset}>
      <div class="flex flex-col gap-8">
        <%= if @class_modality != :never do %>
          <div class="flex flex-col gap-1 flex-1">
            <span required>Days of the week you meet</span>
            <div class="flex flex-wrap gap-2">
              <%= for {value, label} <- @days do %>
                <CustomCheckbox.item
                  form={f}
                  field={:class_days}
                  checked={Enum.member?(@class_days, value)}
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
              <%= Phoenix.HTML.Form.datetime_local_input(f, :start_date, class: "torus-input") %>
            </div>
            <div class="flex flex-col gap-1 flex-1">
              <span required>Course end date</span>
              <%= Phoenix.HTML.Form.datetime_local_input(f, :end_date, class: "torus-input") %>
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
