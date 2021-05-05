defmodule OliWeb.Curriculum.DeleteModal do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  import OliWeb.Curriculum.Utils

  alias Oli.Authoring.Editing.ContainerEditor

  @impl true
  def render(assigns) do
    ~L"""
    <div class="modal" id="delete_<%= @revision.slug %>" tabindex="-1" role="dialog" aria-labelledby="deleteModalLabel" aria-hidden="true" phx-update="ignore">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title" id="deleteModalLabel">Delete <%= resource_type_label(@revision) |> String.capitalize() %></h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            Are you sure you want to delete "<%= @revision.title %>"?
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
            <button
              phx-target="<%= @myself %>"
              phx-click="delete"
              phx-key="enter"
              phx-value-slug="<%= @revision.slug %>"
              class="btn btn-danger">
              Delete <%= resource_type_label(@revision) |> String.capitalize() %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"slug" => slug}, socket) do
    case ContainerEditor.remove_child(
           socket.assigns.container,
           socket.assigns.project,
           socket.assigns.author,
           slug
         ) do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: socket.assigns.return_to)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not remove #{resource_type_label(socket.assigns.revision)} \"#{socket.assigns.revision.title}\"")}
    end
  end

end
