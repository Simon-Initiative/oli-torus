defmodule OliWeb.PublisherLive.Form do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{EmailInput, ErrorTag, Field, Label, TextInput}

  prop(changeset, :changeset, required: true)
  prop(save, :event, required: true)
  prop(display_labels, :boolean, default: true)

  def render(assigns) do
    ~F"""
    <Form for={@changeset} submit={@save}>
      <Field name={:name} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Publisher Name</Label>
          {#if @changeset.data.default}
            <span class="badge badge-info">default</span>
          {/if}
        {/if}
        <TextInput class="form-control" opts={placeholder: "Name", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:email} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Publisher Email</Label>
        {/if}
        <EmailInput class="form-control" opts={placeholder: "Email", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:address} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Publisher Address</Label>
        {/if}
        <TextInput class="form-control" opts={placeholder: "Address", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:main_contact} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Publisher Main Contact</Label>
        {/if}
        <TextInput class="form-control" opts={placeholder: "Main Contact", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <Field name={:website_url} class="form-group">
        {#if @display_labels}
          <Label class="control-label">Publisher Website URL</Label>
        {/if}
        <TextInput class="form-control" opts={placeholder: "Website URL", maxlength: "255"}/>
        <ErrorTag/>
      </Field>

      <button class="form-button btn btn-md btn-primary btn-block mt-3" type="submit">Save</button>
    </Form>
    """
  end
end
