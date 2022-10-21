defmodule OliWeb.Common.Modal.CreateModal do
  @moduledoc """
  LiveView modal for creating an entity from a changeset
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~H"""
    <div class="modal fade show" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <%= form_for @changeset, "#",
            [id: "new-group-form",
            as: :params,
            phx_change: @on_validate,
            phx_submit: @on_create],
            fn f -> %>
              <div class="modal-header">
                <h5 class="modal-title"><%= @title %></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                  <span aria-hidden="true">&times;</span>
                </button>
              </div>
              <div class="modal-body">
                <.form_body form={f} {assigns} />
              </div>
              <div class="modal-footer">
                <button type="button" class="btn btn-link" data-dismiss="modal">Cancel</button>
                <%= submit "Create", class: "btn btn-primary" %>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def form_body(assigns) do
    assigns.form_body_fn.(assigns)
  end
end
