defmodule OliWeb.Curriculum.DeleteModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

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
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
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
    %{
      container: container,
      project: project,
      author: author,
      revision: revision,
      redirect_url: redirect_url
    } = socket.assigns

    case container do
      nil ->
        result =
          Oli.Repo.transaction(fn ->
            revision =
              Oli.Publishing.AuthoringResolver.from_revision_slug(project.slug, revision.slug)

            Oli.Publishing.ChangeTracker.track_revision(project.slug, revision, %{deleted: true})
          end)

        case result do
          {:ok, _} ->
            {:noreply,
             push_patch(socket,
               to: redirect_url
             )}

          _ ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Could not delete #{resource_type_label(revision)} \"#{revision.title}\""
             )}
        end

      _ ->
        case ContainerEditor.remove_child(container, project, author, slug) do
          {:ok, _} ->
            {:noreply,
             push_patch(socket,
               to: redirect_url
             )}

          {:error, _} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "Could not delete #{resource_type_label(revision)} \"#{revision.title}\""
             )}
        end
    end
  end
end
