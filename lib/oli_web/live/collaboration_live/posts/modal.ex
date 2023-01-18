defmodule OliWeb.CollaborationLive.Posts.Modal do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{
    Field,
    TextArea,
    HiddenInput,
    Inputs
  }

  prop id, :string, required: true
  prop title, :string, default: "Edit post"
  prop changeset, :struct, required: true
  prop on_submit, :event, required: true

  def render(assigns) do
    ~F"""
      <div class="modal fade show d-block" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog modal-lg" role="document">
          <div class="modal-content">
            <div class="modal-header pb-0">
              <h4 class="modal-title">{@title}</h4>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>

            <div class="modal-body col-12 mt-2">
              <Form for={@changeset} submit={@on_submit} opts={autocomplete: "off"}>
                <HiddenInput field={:user_id} />
                <HiddenInput field={:section_id} />
                <HiddenInput field={:resource_id} />

                <HiddenInput field={:parent_post_id} />
                <HiddenInput field={:thread_root_id} />

                <Inputs for={:content}>
                  <Field name={:message} class="form-group">
                    <TextArea class="form-control" opts={placeholder: "Write message..."}/>
                  </Field>
                </Inputs>

                <button type="submit" class="btn btn-sm btn-primary float-right">Save</button>
              </Form>
            </div>
          </div>
        </div>
      </div>
    """
  end
end
