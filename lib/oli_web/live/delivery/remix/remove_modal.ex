defmodule OliWeb.Delivery.Remix.RemoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Authoring.Editing.ContainerEditor
  alias Oli.Publishing.HierarchyNode

  def render(%{node: %HierarchyNode{slug: slug, revision: revision}} = assigns) do
    ~L"""
    <div class="modal fade show" id="delete_<%= slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Remove <%= resource_type_label(revision) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              Are you sure you want to remove <b><%= revision.title %></b>?
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="RemoveModal.cancel">Cancel</button>
              <button
                phx-click="RemoveModal.remove"
                phx-key="enter"
                phx-value-slug="<%= slug %>"
                onclick="$('#delete_<%= slug %>').modal('hide')"
                class="btn btn-danger">
                Remove
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
