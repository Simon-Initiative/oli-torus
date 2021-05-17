defmodule OliWeb.Curriculum.DeleteModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Editing.ContainerEditor

  def render(%{revision: revision} = assigns) do
    ~L"""
    <div class="modal fade show" id="delete_<%= revision.slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Delete <%= resource_type_label(revision) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              Are you sure you want to delete "<%= revision.title %>"?
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel">Cancel</button>
              <button
                phx-target="<%= @myself %>"
                phx-click="delete"
                phx-key="enter"
                phx-value-slug="<%= revision.slug %>"
                onclick="$('#delete_<%= revision.slug %>').modal('hide')"
                class="btn btn-danger">
                Delete <%= resource_type_label(revision) |> String.capitalize() %>
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("delete", %{"slug" => slug}, socket) do
    %{container: container, project: project, author: author, revision: revision} = socket.assigns

    case ContainerEditor.remove_child(container, project, author, slug) do
      {:ok, _} ->
        {:noreply, push_patch(socket, to: Routes.container_path(socket, :index, project.slug, container.slug))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete #{resource_type_label(revision)} \"#{revision.title}\"")}
    end
  end
end
