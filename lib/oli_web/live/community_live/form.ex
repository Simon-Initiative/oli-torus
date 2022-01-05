defmodule OliWeb.CommunityLive.Form do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{Checkbox, ErrorTag, Field, Label, TextArea, TextInput}

  prop(changeset, :changeset, required: true)
  prop(save, :event, required: true)
  prop(display_labels, :boolean, default: true)

  def render(assigns) do
    ~F"""
    <Form for={@changeset} submit={@save}>
      <Field name={:name} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Community Name</Label>
        {/if}
        <TextInput class="form-control" opts={placeholder: "Name", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:description} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Community Description</Label>
        {/if}
        <TextArea class="form-control" rows="4" opts={placeholder: "Description"}/>
      </Field>

      <Field name={:key_contact} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Community Contact</Label>
        {/if}
        <TextInput class="form-control" opts={placeholder: "Key Contact", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:global_access} class="form-check">
        <Checkbox class="form-check-input"/>
        <Label class="form-check-label" text="Access to Global Project or Products"/>
      </Field>

      <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
    </Form>
    """
  end
end
