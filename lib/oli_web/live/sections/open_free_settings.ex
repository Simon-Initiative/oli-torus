defmodule OliWeb.Sections.OpenFreeSettings do
  use Surface.Component

  alias Surface.Components.{Form, Field, Select}
  alias Surface.Components.Form.{Field, Label, DateInput, Select, Checkbox}
  alias OliWeb.Common.Properties.{Group}
  import OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Changeset
  alias Oli.Predefined

  def timezones() do
    Predefined.timezones()
  end

  def format(nil), do: nil

  def format(date_time_utc) do
    Timex.format!(date_time_utc, "%Y-%m-%d", :strftime)
  end

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true

  def render(assigns) do
    ~F"""
    <Group label="LMS-Lite" description="Settings related to LMS-Lite delivery">
      <Field name={:registration_open} class="form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :registration_open)}/>
        <Label class="form-check-label"/>
      </Field>
      <div class="form-row mt-4">
        <Field name={:start_date} class="mr-3">
          <Label/>
          <DateInput class="form-control" value={format(get_field(@changeset, :start_date))} opts={disabled: @disabled}/>
        </Field>
        <Field name={:end_date}>
          <Label/>
          <DateInput class="form-control" value={format(get_field(@changeset, :end_date))} opts={disabled: @disabled}/>
        </Field>
      </div>
      <Field name={:timezone} class="mt-2">
        <Label/>
        <Select class="form-control" form="section" field="timezone" options={timezones()} selected={@changeset.data.timezone}/>
      </Field>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
