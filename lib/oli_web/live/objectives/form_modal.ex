defmodule OliWeb.ObjectivesLive.FormModal do
  use Surface.Component

  alias Surface.Components.Form
  alias Surface.Components.Form.{ErrorTag, Field, HiddenInput, TextInput}

  prop id, :string, required: true
  prop changeset, :any, required: true
  prop on_click, :event, required: true
  prop action, :atom, default: :new

  def render(assigns) do
    ~F"""
      <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="show-existing-sub-modal" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog modal-lg" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">{title(@action)}</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <p>At the end of the course, students should be able to...</p>
              <div class="col-span-12 mt-4">
                <Form for={@changeset} submit={@on_click}>
                  <HiddenInput field={:slug}/>
                  <HiddenInput field={:parent_slug}/>

                  <Field name={:title} class="form-group">
                    <TextInput class="form-control" opts={placeholder: "e.g. Recognize the structures of amino acids, carbohydrates, lipids..."}/>
                    <ErrorTag/>
                  </Field>

                  <button class="form-button btn btn-md btn-primary btn-block w-auto float-right" type="submit">{button(@action)}</button>
                </Form>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end

  defp title(:edit), do: "Edit Objective"
  defp title(_), do: "New Objective"

  defp button(:edit), do: "Save"
  defp button(_), do: "Create"
end
