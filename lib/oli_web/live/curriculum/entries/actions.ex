defmodule OliWeb.Curriculum.Actions do
  @moduledoc """
  Curriculum item entry actions component.
  """

  use OliWeb, :live_component

  import OliWeb.Curriculum.Utils

  def render(assigns) do
    ~L"""
    <div class="entry-actions">
      <div class="dropdown">
        <button class="btn dropdown-toggle" type="button" id="dropdownMenuButton" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false"></button>
        <div class="dropdown-menu dropdown-menu-right" aria-labelledby="dropdownMenuButton">
          <button type="button" class="dropdown-item" data-toggle="modal" data-target="#details_<%= @child.slug %>"><i class="las la-sliders-h mr-1"></i> Details</button>
          <button type="button" class="dropdown-item" data-toggle="modal" data-target="#move_<%= @child.slug %>"><i class="las la-arrow-circle-right mr-1"></i> Move to...</button>
          <div class="dropdown-divider"></div>
          <button type="button" class="dropdown-item text-danger" data-toggle="modal" data-target="#delete_<%= @child.slug %>"><i class="lar la-trash-alt mr-1"></i> Delete</button>
        </div>
      </div>

      <!-- Details Modal -->
      <%= live_component @socket, OliWeb.Curriculum.DetailsModal,
        container: @container,
        id: @child.id,
        revision: @child,
        project: @project,
        return_to: Routes.container_path(@socket, :index, @project.slug, @container.slug) %>

      <!-- Move Modal -->
      <div class="modal" id="move_<%= @child.slug %>" tabindex="-1" role="dialog" aria-labelledby="moveModalLabel" aria-hidden="true" phx-update="ignore">
        <div class="modal-dialog" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title" id="moveModalLabel">Move <%= resource_type_label(@child) |> String.capitalize() %></h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <%= if is_container?(@child) do %>
              <% else %>
              <% end %>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <button type="button" class="btn btn-primary">Move</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Delete Modal -->
      <%= live_component @socket, OliWeb.Curriculum.DeleteModal,
        container: @container,
        id: @child.id,
        revision: @child,
        project: @project,
        author: @author,
        return_to: Routes.container_path(@socket, :index, @project.slug, @container.slug) %>
    </div>
    """
  end

end
