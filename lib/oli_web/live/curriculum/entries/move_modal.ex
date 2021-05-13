defmodule OliWeb.Curriculum.MoveModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import OliWeb.Curriculum.Utils

  alias OliWeb.Curriculum.HierarchyPicker

  def render(assigns) do
    ~L"""
    <div class="modal fade show" style="display: block" id="move_<%= @revision.slug %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Move <%= resource_type_label(@revision) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
            <%= live_component @socket, HierarchyPicker,
              id: "hierarchy_picker_#{@revision.slug}",
              project: @project,
              container: @container,
              container: @container,
              revision: @revision,
              breadcrumbs: @breadcrumbs,
              children: @children,
              numberings: @numberings %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel">Cancel</button>
              <button type="submit"
                class="btn btn-primary"
                onclick="$('#move_<%= @revision.slug %>').modal('hide')"
                phx-click="move_item"
                phx-value-selection="<%= @selection %>"
                <%= if can_move?(@old_container, @selection) , do: "", else: "disabled" %>>
                Move
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end

  defp can_move?(old_container, selected_slug) do
    selected_slug != nil && selected_slug != old_container.slug
  end
end
