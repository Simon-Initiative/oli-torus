defmodule OliWeb.Sections.MainDetails do
  use Surface.Component

  alias Surface.Components.Form.{Field, Label, TextInput, Select, ErrorTag}

  import Ecto.Changeset

  prop changeset, :any, required: true
  prop disabled, :boolean, required: true
  prop is_admin, :boolean, required: true
  prop brands, :list, required: true

  def render(assigns) do
    ~F"""
    <div>
      <Field name={:title} class="form-label-group">
        <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:description} class="form-label-group">
        <div class="d-flex justify-content-between"><Label/><ErrorTag class="help-block"/></div>
        <TextInput class="form-control" opts={disabled: @disabled}/>
      </Field>
      <Field name={:brand_id} class="mt-2">
        <Label>Brand</Label>
        <Select class="form-control" prompt="None" form="section" field="brand_id" options={@brands} selected={get_field(@changeset, :brand_id)}/>
      </Field>
      <button class="btn btn-primary mt-3" type="submit">Save</button>
    </div>
    """
  end
end
