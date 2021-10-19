defmodule OliWeb.Sections.MainDetails do
  use Surface.Component

  alias Surface.Components.Form.{Field, Label, TextInput, Select}

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true
  prop brands, :list, required: true

  def render(assigns) do
    ~F"""
    <div>
      <Field name={:title}>
        <Label/>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:description}>
        <Label/>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:brand_id} class="mt-2">
        <Label>Brand</Label>
        <Select class="form-control" form="section" field="brand_id" options={@brands} selected={@changeset.data.brand_id}/>
      </Field>
      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </div>
    """
  end
end
