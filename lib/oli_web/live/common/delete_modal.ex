defmodule OliWeb.Common.DeleteModal do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{Field, TextInput}

  prop id, :string, required: true
  prop description, :string, required: true
  prop entity_name, :string, required: true
  prop entity_type, :string, required: true
  prop delete_enabled, :boolean, required: true
  prop validate, :event, required: true
  prop delete, :event, required: true

  def render(assigns) do
    ~F"""
    <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="delete-modal" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Are you absolutely sure?</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
          </div>
          <div class="modal-body">
            <div class="container form-container">
              <div class="mb-3">{@description}</div>
              <div>
                <p>Please type <strong>{@entity_name}</strong> below to confirm.</p>
              </div>
              <Form for={String.to_atom(@entity_type)} submit={@delete} change={@validate}>
                <Field name={:name} class="form-group">
                  <TextInput class="form-control" opts={placeholder: @entity_name}/>
                </Field>
                <div class="d-flex">
                  <button class="btn btn-outline-danger mt-2 flex-fill" type="submit" onclick={"$('##{@id}').modal('hide')"} disabled={!@delete_enabled}>
                    Delete this {@entity_type}
                  </button>
                </div>
              </Form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
