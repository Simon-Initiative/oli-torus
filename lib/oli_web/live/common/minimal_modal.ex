defmodule OliWeb.Common.MinimalModal do

  use Phoenix.LiveComponent

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
        </div>
      </div>
    </div>
    """
  end
end
