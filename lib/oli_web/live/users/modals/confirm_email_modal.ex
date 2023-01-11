defmodule OliWeb.Accounts.Modals.ConfirmEmailModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~H"""
    <div class="modal fade show" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Confirm Email</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <p class="mb-4">Are you sure you want to confirm email for <b><%= @user.email %></b>?</p>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
              <button
                phx-click="confirm_email"
                phx-key="enter"
                phx-value-id={@user.id}
                class="btn btn-success">
                Confirm
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
