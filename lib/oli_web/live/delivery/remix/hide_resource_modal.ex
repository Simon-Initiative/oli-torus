defmodule OliWeb.Delivery.Remix.HideResourceModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  alias Oli.Delivery.Hierarchy.HierarchyNode

  def render(%{node: %HierarchyNode{}} = assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={"hide_#{@node.uuid}"}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">
              <%= get_label_action(@node) |> String.capitalize() %>
              <%= @node.revision.title |> String.capitalize() %>
            </h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
            </button>
          </div>
          <div class="modal-body">
            Are you sure you want to <%= get_label_action(@node) %> <b><%= @node.revision.title %></b>?
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click="HideResourceModal.cancel"
            >
              Cancel
            </button>
            <button
              phx-click="HideResourceModal.toggle"
              phx-key="enter"
              phx-value-uuid={@node.uuid}
              class="btn btn-danger"
            >
              <%= get_label_action(@node) |> String.capitalize() %>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_label_action(node), do: if(node.section_resource.hidden, do: "show", else: "hide")
end
