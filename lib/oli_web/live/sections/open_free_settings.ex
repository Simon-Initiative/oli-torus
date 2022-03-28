defmodule OliWeb.Sections.OpenFreeSettings do
  use OliWeb, :surface_component

  alias Surface.Components.{Field, Select}
  alias Surface.Components.Form.{Field, Label, DateTimeLocalInput, Select, Checkbox, ErrorTag}
  alias OliWeb.Common.Properties.{Group}
  alias Oli.Predefined
  import Ecto.Changeset

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true

  def timezone_localized_datetime(nil, _timezone), do: nil

  def timezone_localized_datetime(%DateTime{} = datetime, timezone) do
    case maybe_localized_datetime(datetime, timezone) do
      {:localized, datetime} ->
        datetime

      datetime ->
        datetime
    end
  end

  def render(assigns) do
    ~F"""
    <Group label="Direct Delivery" description="Direct Delivery section settings">
      <Field name={:registration_open} class="form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :registration_open)}/>
        <Label class="form-check-label"/>
      </Field>

      <Field name={:requires_enrollment} class="mt-2 form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :requires_enrollment)}/>
        <Label class="form-check-label"/>
      </Field>

      <Field name={:confirm_students_on_creation} class="mt-2 form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :confirm_students_on_creation)}/>
        <Label class="form-check-label">Omit student email verification</Label>
      </Field>

      <Field name={:timezone} class="mt-2">
        <Label/>
        <Select class="form-control" form="section" field="timezone" options={Predefined.timezones()} selected={get_field(@changeset, :timezone)}/>
      </Field>

      <div class="form-row mt-4">
        <Field name={:start_date} class="mr-3 form-label-group">
          <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
          <DateTimeLocalInput class="form-control" value={timezone_localized_datetime(get_field(@changeset, :start_date), get_field(@changeset, :timezone))} opts={disabled: @disabled}/>
        </Field>
        <Field name={:end_date} class="form-label-group">
          <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
          <DateTimeLocalInput class="form-control" value={timezone_localized_datetime(get_field(@changeset, :end_date), get_field(@changeset, :timezone))} opts={disabled: @disabled}/>
        </Field>
      </div>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
