defmodule OliWeb.Delivery.Remix.RemoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(%{node: %HierarchyNode{}} = assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={"delete_#{@node.uuid}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              Remove {resource_type_label(@node.revision) |> String.capitalize()}
            </h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            Are you sure you want to remove <b><%= @node.revision.title %></b>?
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click="RemoveModal.cancel"
            >
              Cancel
            </button>
            <button
              phx-click="RemoveModal.remove"
              phx-key="enter"
              phx-value-uuid={@node.uuid}
              class="btn btn-danger"
            >
              Remove
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
