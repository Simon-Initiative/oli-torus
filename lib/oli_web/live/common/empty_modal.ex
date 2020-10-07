defmodule OliWeb.Common.EmptyModal do

  @moduledoc """
  An empty modal. All content and actions must be defined by the client.

  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="<%= @modal_id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch" data-backdrop="false">
      <div class="modal-dialog" role="document" style="white-space: normal">
        <div class="modal-content">
          <div class="modal-body">
            <%= @inner_content.([]) %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
