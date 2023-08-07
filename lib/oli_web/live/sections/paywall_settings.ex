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

  defp payment_options_choices do
    [
      {"Pay by credit card only", "direct"},
      {"Pay by payment code only", "deferred"},
      {"Pay by credit card or payment code", "direct_and_deferred"}
    ]
  end

  def render(assigns) do
    ~F"""
    <Group.render label="Payment Settings" description="Settings related to requried student fee and optional grace periody">
      <Field name={:requires_payment} class="form-check">
        <Checkbox class="form-check-input" value={get_field(@changeset, :requires_payment)} opts={disabled: @disabled}/>
        <Label class="form-check-label"/>
      </Field>
      <Field name={:amount} class="mt-2 form-label-group">
        <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
        <TextInput class="form-control" opts={disabled: @disabled or !get_field(@changeset, :requires_payment)}/>
      </Field>
      <Field name={:payment_options}>
        <Label/>
        <Select
          class="form-control" form="section" field="payment_options"
          opts={disabled: @disabled or !get_field(@changeset, :payment_options) or !get_field(@changeset, :payment_options)}
          options={payment_options_choices()} selected={get_field(@changeset, :payment_options)}/>
      </Field>
      {#unless get_field(@changeset, :open_and_free)}
        <Field name={:pay_by_institution} class="form-check">
          <Checkbox class="form-check-input" value={get_field(@changeset, :pay_by_institution)} opts={disabled: @disabled or !get_field(@changeset, :requires_payment)}/>
          <Label class="form-check-label"/>
        </Field>
      {/unless}
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
          options={strategies()} selected={get_field(@changeset, :grace_period_strategy)}/>
      </Field>

      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </Group.render>
    """
  end
end
