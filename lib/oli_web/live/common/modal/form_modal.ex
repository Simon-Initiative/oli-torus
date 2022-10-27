defmodule OliWeb.Common.Modal.FormModal do
  @moduledoc """
  LiveView modal for creating an entity from a changeset
  """
  use Phoenix.LiveComponent
  use Phoenix.HTML

  attr(:id, :string, required: true)
  attr(:changeset, Ecto.Changeset, required: true)
  attr(:on_validate, :string, required: true)
  attr(:on_submit, :string, required: true)
  attr(:title, :string, required: true)
  attr(:submit_label, :string, default: "Submit")

  def form_modal(assigns) do
    ~H"""
    <div class="modal fade show" tabindex="-1" id={@id} role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
          <%= form_for @changeset, "#",
            [as: :params,
              phx_change: @on_validate,
              phx_submit: @on_submit],
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
                <%= submit @submit_label, class: "btn btn-primary" %>
              </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp form_body(assigns) do
    assigns.form_body_fn.(assigns)
  end
end
