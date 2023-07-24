defmodule OliWeb.Sections.StartEnd do
  use OliWeb, :surface_component

  alias Surface.Components.Field
  alias Surface.Components.Form.{Field, Label, DateTimeLocalInput, ErrorTag}
  alias OliWeb.Common.FormatDateTime

  prop(changeset, :any, required: true)
  prop(disabled, :boolean, required: true)
  prop(is_admin, :boolean, required: true)
  prop(ctx, :struct, required: true)

  def render(assigns) do
    start_date =
      assigns.changeset
      |> Ecto.Changeset.get_field(:start_date)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    end_date =
      assigns.changeset
      |> Ecto.Changeset.get_field(:end_date)
      |> FormatDateTime.convert_datetime(assigns.ctx)

    ~F"""
      <div class="flex flex-col gap-2 mt-4">
        <Field name={:start_date} class="form-label-group">
          <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
          <DateTimeLocalInput class="form-control" value={start_date} opts={disabled: @disabled}/>
        </Field>
        <Field name={:end_date} class="form-label-group">
          <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
          <DateTimeLocalInput class="form-control" value={end_date} opts={disabled: @disabled}/>
        </Field>
        <div class="mt-3">
          <button class="btn btn-primary" type="submit">Save</button>
        </div>
      </div>
    """
  end
end
