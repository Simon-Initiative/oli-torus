defmodule OliWeb.Sections.StartEnd do
  use OliWeb, :html

  attr(:changeset, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-2 mt-4">
      <div class="form-label-group">
        <.input
          type="datetime-local"
          field={@changeset[:start_date]}
          label="Start date"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="datetime-local"
          field={@changeset[:end_date]}
          label="End date"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="form-label-group">
        <.input
          type="time"
          field={@changeset[:preferred_scheduling_time]}
          label="Scheduling Preferred Time"
          class="form-control"
          disabled={@disabled}
          ctx={@ctx}
        />
      </div>
      <div class="mt-3">
        <button class="btn btn-primary" type="submit">Save</button>
      </div>
    </div>
    """
  end
end
