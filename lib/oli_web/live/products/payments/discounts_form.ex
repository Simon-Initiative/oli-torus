defmodule OliWeb.Products.Payments.DiscountsForm do
  use Surface.Component

  import Ecto.Changeset

  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, Label, Select, NumberInput, TextInput}
  alias OliWeb.Common.Properties.ReadOnly

  prop changeset, :changeset, required: true
  prop discount, :any, required: true
  prop save, :event, required: true
  prop change, :event, required: true
  prop clear, :event, required: true
  prop institution_name, :string

  def render(assigns) do
    ~F"""
      <Form for={@changeset} submit={@save} change={@change}>
        <ReadOnly label="Institution" value={@institution_name}/>

        <Field name={:type} class="form-group">
          <Label />
          <Select class="form-control" options={"Percentage": "percentage", "Fixed amount": "fixed_amount"} selected={get_field(@changeset, :type)}/>
          <ErrorTag/>
        </Field>

        <Field name={:amount} class="form-group">
          <Label/>
          <TextInput class="form-control" opts={disabled: get_field(@changeset, :type) == :percentage} />
          <ErrorTag/>
        </Field>

        <Field name={:percentage} class="form-group">
          <Label/>
          <NumberInput class="form-control" opts={disabled: get_field(@changeset, :type) == :fixed_amount} />
          <ErrorTag/>
        </Field>

        <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
      </Form>

      <button class="btn btn-md btn-outline-danger float-right mt-3" phx-click="clear" disabled={is_nil(@discount)}>Clear</button>
    """
  end
end
