defmodule OliWeb.Users.Actions do
  use OliWeb, :html

  alias OliWeb.Common.Properties.ReadOnly

  attr(:user_id, :integer, required: true)
  attr(:account_locked, :boolean, required: true)
  attr(:email_confirmation_pending, :boolean, required: true)
  attr(:password_reset_link, :string, default: "")

  def render(assigns) do
    ~H"""
    <div>
      <div class="form-group">
        <.button variant={:link} phx-click="generate_reset_password_link" phx-value-id={@user_id}>
          <i class="fa-solid fa-key"></i> Generate Reset Password Link
        </.button>

        <ReadOnly.render label="" show_copy_btn={true} value={@password_reset_link} />

        <p :if={@password_reset_link not in [nil, ""]} class="mb-1">
          This link will expire in 24 hours.
        </p>
      </div>

      <%= if @email_confirmation_pending do %>
        <.button
          variant={:primary}
          class="mt-2"
          phx-click="resend_confirmation_link"
          phx-value-id={@user_id}
        >
          Resend confirmation link
        </.button>
        <.button
          variant={:primary}
          class=""
          phx-click="show_confirm_email_modal"
          phx-value-id={@user_id}
        >
          Confirm email
        </.button>

        <div class="dropdown-divider"></div>
      <% else %>
        <.button
          variant={:primary}
          class="mt-2"
          phx-click="send_reset_password_link"
          phx-value-id={@user_id}
        >
          Send password reset link
        </.button>

        <div class="dropdown-divider"></div>
      <% end %>

      <%= if @account_locked do %>
        <.button
          variant={:warning}
          class="mt-2"
          phx-click="show_unlock_account_modal"
          phx-value-id={@user_id}
        >
          Unlock Account
        </.button>
      <% else %>
        <.button
          variant={:warning}
          class="mt-2"
          phx-click="show_lock_account_modal"
          phx-value-id={@user_id}
        >
          Lock Account
        </.button>
      <% end %>

      <div class="dropdown-divider"></div>

      <.button
        variant={:danger}
        class="mt-6"
        phx-click="show_delete_account_modal"
        phx-value-id={@user_id}
      >
        Delete Account
      </.button>
    </div>
    """
  end
end
