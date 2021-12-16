defmodule OliWeb.Sections.PaywallSettings do
  use Surface.Component

  alias Surface.Components.{Field, Select}

  alias Surface.Components.Form.{
    Field,
    Label,
    Select,
    TextInput,
    NumberInput,
    Checkbox,
    ErrorTag
  }

  alias OliWeb.Common.Properties.{Group}
  import Ecto.Changeset

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true

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
        <Checkbox class="form-check-input" value={get_field(@changeset, :requires_payment)} opts={disabled: @disabled}/>
        <Label class="form-check-label"/>
      </Field>
      <Field name={:amount} class="mt-2 form-label-group">
        <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
        <TextInput class="form-control" opts={disabled: @disabled or !get_field(@changeset, :requires_payment)}/>
      </Field>
      <Field name={:has_grace_period} class="form-check mt-4">
        <Checkbox class="form-check-input" value={get_field(@changeset, :has_grace_period)} opts={disabled: @disabled or !get_field(@changeset, :requires_payment)}/>
        <Label class="form-check-label"/>
      </Field>
      <Field name={:grace_period_days} class="form-label-group">
        <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
        <NumberInput class="form-control" opts={disabled: @disabled or !get_field(@changeset, :requires_payment) or !get_field(@changeset, :has_grace_period)}/>
      </Field>
      <Field name={:grace_period_strategy}>
        <Label/>
        <Select
          class="form-control" form="section" field="grace_period_strategy"
          opts={disabled: @disabled or !get_field(@changeset, :requires_payment) or !get_field(@changeset, :has_grace_period)}
          options={strategies()} selected={@changeset.data.grace_period_strategy}/>
      </Field>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group>
    """
  end
end
