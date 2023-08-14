defmodule OliWeb.Sections.StartEnd do
  use OliWeb, :surface_component
  use OliWeb, :html

  alias OliWeb.Common.FormatDateTime

  attr(:changeset, :any, required: true)
  attr(:disabled, :boolean, required: true)
  attr(:is_admin, :boolean, required: true)
  attr(:ctx, :map, required: true)

  def render(assigns) do
    start_date =
      assigns.changeset
      |> Ecto.Changeset.get_field(:start_date)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    end_date =
      assigns.changeset
      |> Ecto.Changeset.get_field(:end_date)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    assigns = assign(assigns, start_date: start_date, end_date: end_date)

    ~H"""
    <div class="flex flex-col gap-2 mt-4">
      <div class="form-label-group">
        <div class="flex justify-between">
          <label for="section_start_date">Start date</label>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :start_date)}>
            <%= translate_error(error) %>
          </.error>
        </div>
        <.input
          id="section_start_date"
          type="datetime-local"
          name="section[start_date]"
          class="form-control"
          value={@start_date}
          disabled={@disabled}
        />
      </div>
      <div class="form-label-group">
        <div class="flex justify-between">
          <label for="section_end_date">Start date</label>
          <.error :for={error <- Keyword.get_values(@changeset.errors || [], :end_date)}>
            <%= translate_error(error) %>
          </.error>
        </div>
        <.input
          id="section_end_date"
          type="datetime-local"
          name="section[end_date]"
          class="form-control"
          value={@end_date}
          disabled={@disabled}
        />
      </div>
      <div class="mt-3">
        <button class="btn btn-primary" type="submit">Save</button>
      </div>
    </div>
    """
  end
end
