defmodule OliWeb.Admin.CollaborativeSpace.EditModal do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, TextInput, Inputs}

  prop id, :string, required: true
  prop on_click, :event, required: true
  prop changeset, :struct, required: true

  def render(assigns) do
    ~F"""
      <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog modal-lg" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Edit post</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>
            <div class="modal-body">
              <div class="col-12 mt-2">
                <Form for={@changeset} submit={@on_click} opts={autocomplete: "off"}>
                  <Inputs for={:content} >
                    <Field name={:message} class="form-group">
                      <TextInput class="form-control"/>
                      <ErrorTag/>
                    </Field>
                  </Inputs>
                  <button class="form-button btn btn-md btn-primary btn-block w-auto float-right" type="submit">Save</button>
                </Form>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end
end
