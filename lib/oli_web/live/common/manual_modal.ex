defmodule OliWeb.Common.ManualModal do

  @moduledoc """
  A reusable LivewComponent for a Bootstrap modal, one that is manually controlled via JavaScript, and that
  must be added and removed from a parent LiveView programmatically when it needs to be shown.

  This component should be used in place of `OliWeb.Common.Modal` when there is a need to programmatically
  vary the content that the modal displays from invocation to invocation.  The only way to do this
  is to completely remove the component from the DOM and remount it with the new content.  Doing this, however,
  forces the launching of the modal to be done via JavaScript (notice the phx-hook that is present on
  the root div of this modal)

  Minimal example usage specifying only the required properties:

  ```
  <%= live_component @socket, ManualModal, title: "Confirm your request", modal_id: "my_unique_modal_id", ok_action: "confirm" do %>
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
    {:ok, assign(socket,
      ok_label: "Ok",
      ok_style: "btn-primary")
    }
  end

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="<%= @modal_id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered modal-lg" role="document">
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
            <button type="button" class="btn btn-secondary" data-dismiss="modal" phx-click="cancel_modal">Cancel</button>
            <button type="button" class="btn <%= @ok_style %>" data-dismiss="modal" phx-click="<%= @ok_action %>"><%= @ok_label %></button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
