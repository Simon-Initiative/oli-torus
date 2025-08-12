defmodule OliWeb.Sections.StartEnd do
  use OliWeb, :html

  attr(:form, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:ctx, :map, required: true)

  defp timezone_options do
    Tzdata.zone_list()
    |> Enum.map(&{&1, &1})
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mt-4">
      <div class="form-label-group">
        <.input
          type="datetime-local"
          field={@form[:start_date]}
          label="Start date"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="datetime-local"
          field={@form[:end_date]}
          label="End date"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="time"
          field={@form[:preferred_scheduling_time]}
          label="Scheduling Preferred Time"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="select"
          field={@form[:timezone]}
          label="Course Timezone"
          class="form-control"
          disabled={@disabled}
          options={timezone_options()}
        />
      </div>
      <div class="mt-3">
        <button class="btn btn-primary" type="submit">Save</button>
      </div>
    </div>
    """
  end
end
