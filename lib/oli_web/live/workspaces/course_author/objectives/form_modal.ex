defmodule OliWeb.Workspaces.CourseAuthor.Objectives.FormModal do
  use OliWeb, :html

  attr(:action, :atom, default: :new)
  attr(:form, :any, required: true)
  attr(:id, :string, required: true)
  attr(:on_click, :any, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      style="display: block"
      tabindex="-1"
      role="dialog"
      aria-labelledby="show-existing-sub-modal"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><%= title(@action) %></h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            <p>At the end of the course, students should be able to...</p>
            <div class="col-span-12 mt-4">
              <.form id={"#{@id}_form"} for={@form} phx-submit={@on_click}>
                <.input hidden field={@form[:slug]} />
                <.input hidden field={@form[:parent_slug]} />
                <div class=".f-group">
                  <.input
                    field={@form[:title]}
                    class="form-control"
                    placeholder="e.g. Recognize the structures of amino acids, carbohydrates, lipids..."
                  />
                </div>

                <button
                  class="form-button btn btn-md btn-primary btn-block w-auto float-right mt-4"
                  type="submit"
                >
                  <%= button_text(@action) %>
                </button>
              </.form>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp title(:edit), do: "Edit Objective"
  defp title(_), do: "New Objective"

  defp button_text(:edit), do: "Save"
  defp button_text(_), do: "Create"
end
