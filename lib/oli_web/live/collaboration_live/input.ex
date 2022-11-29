defmodule OliWeb.CollaborationLive.Input do
  use Surface.Component

  prop button_text, :string, required: true
  prop parent_id, :integer, default: nil
  prop root_id, :integer, default: nil
  prop message_text, :string, required: true
  prop id, :string, required: true
  prop changeset, :changeset, required: true

  prop typing, :event, required: true
  prop stop_typing, :event, required: true
  prop create_post, :event, required: true

  alias Surface.Components.Form

  alias Surface.Components.Form.{
    Field,
    TextInput,
    HiddenInput,
    Inputs
  }

  def render(assigns) do
    ~F"""
    <div class="ml-auto mt-4">
      <Form for={@changeset} submit="create_post" change="typing" opts={autocomplete: "off"}>
        <HiddenInput field={:parent_post_id} value={@parent_id}/>
        <HiddenInput field={:thread_root_id} value={@root_id}/>
        <Inputs for={:content} >
          <Field name={:message} class="form-group">
            <TextInput class="form-control" id={@id} blur="stop_typing" opts={placeholder: "Write message"}/>
          </Field>
        </Inputs>
        <div class="d-flex justify-content-end"><button type="submit" class="btn btn-sm btn-primary">{@button_text}</button></div>
      </Form>
    </div>
    """
  end
end
