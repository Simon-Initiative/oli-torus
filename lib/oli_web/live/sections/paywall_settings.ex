defmodule OliWeb.Sections.PaywallSettings do
  use Surface.Component

  alias Surface.Components.{Form, Field, Select}

  alias Surface.Components.Form.{
    Field,
    Label,
    DateInput,
    Select,
    TextInput,
    NumberInput,
    Checkbox
  }

  alias OliWeb.Common.Properties.{Group}
  import OliWeb.Common.Utils
  alias OliWeb.Router.Helpers, as: Routes
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  import Ecto.Changeset

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true

  defp strategies do
    [
      {"Relative to section start", "relative_to_section"},
      {"Relative to student first access", "relative_to_student"}
    ]
  end

  def render(assigns) do
    ~F"""
    <Group label="Payment Settings" description="Settings related to requried student fee and optional grace periody">
      <Field name={:requires_payment} class="form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :requires_payment)}/>
        <Label class="form-check-label"/>
      </Field>
      <Field name={:amount} class="mt-2">
        <Label/>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:has_grace_period} class="form-check mt-4">
        <Checkbox class="form-check-input" value={get_field(@changeset, :has_grace_period)}/>
        <Label class="form-check-label"/>
      </Field>
      <Field name={:grace_period_days} class="mt-3">
        <Label/>
        <NumberInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:grace_period_strategy}>
        <Label/>
        <Select class="form-control" form="section" field="timezone" options={strategies()} selected={@changeset.data.grace_period_strategy}/>
      </Field>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
