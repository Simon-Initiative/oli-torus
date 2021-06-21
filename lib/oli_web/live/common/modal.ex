defmodule OliWeb.Common.Modal do
  @moduledoc """
  A reusable LivewComponent for a Bootstrap modal.

  Minimal example usage specifying only the required properties:

  ```
  <%= live_component Modal, title: "Confirm your request", modal_id: "my_unique_modal_id", ok_action: "confirm" do %>
    <p class="mb-4">Are you sure you want to do this?</p>
  <% end %>
  ```

  Required properties:

  `title`: The string title that the modal will display
  `modal_id`: The DOM id that will be attached to this modal. This is the id that another part of the UI needs
              to target to trigger the modal
  'ok_action': The phx-click action to invoke upon clicking the 'Ok' button

  Optional properties:

  `ok_label`: The label to use for the 'Ok' button, defaults to 'Ok'
  `ok_style`: The Bootstrap button style to use for the 'Ok' button, defaults to `btn-primary`

  """

  use Phoenix.LiveComponent

  def mount(socket) do
    # Default property values
    {:ok,
     assign(socket,
       ok_label: "Ok",
       ok_style: "btn-primary"
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="modal fade" id="<%= @modal_id %>" tabindex="-1" role="dialog" aria-hidden="true">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title"><%= @title %></h5>
            <button type="button" class="close" data-dismiss="modal" aria-label="Close">
              <span aria-hidden="true">&times;</span>
            </button>
          </div>
          <div class="modal-body">
            <%= render_block(@inner_block) %>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
            <button type="button" class="btn <%= @ok_style %>" data-dismiss="modal" phx-click="<%= @ok_action %>"><%= @ok_label %></button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
