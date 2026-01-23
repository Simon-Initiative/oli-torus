defmodule OliWeb.Users.Actions do
  use OliWeb, :html

  alias OliWeb.Common.Properties.ReadOnly
  alias OliWeb.Icons

  attr(:user_id, :integer, required: true)
  attr(:account_locked, :boolean, required: true)
  attr(:email_confirmation_pending, :boolean, required: true)
  attr(:password_reset_link, :string, default: "")

  def render(assigns) do
    ~H"""
    <div>
      <div class="form-group">
        <.button
          variant={:primary}
          class="inline-flex items-center justify-center"
          phx-click="generate_reset_password_link"
          phx-value-id={@user_id}
        >
          Generate Reset Password Link
        </.button>

        <div class="mt-1">
          <ReadOnly.render label="" show_copy_btn={true} value={@password_reset_link} />
        </div>

        <p :if={@password_reset_link not in [nil, ""]} class="mb-1">
          This link will expire in 24 hours.
        </p>
      </div>

      <%= if @email_confirmation_pending do %>
        <.button
          variant={:primary}
          class="mt-1"
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

        <div class="dropdown-divider my-2"></div>
      <% else %>
        <div class="mt-1">
          <a
            href="#"
            class="inline-flex items-center gap-1 text-Text-text-button hover:text-Text-text-button-hover hover:underline font-semibold text-sm leading-4"
            phx-click="send_reset_password_link"
            phx-value-id={@user_id}
          >
            Send password reset link
            <Icons.send class="stroke-Text-text-button group-hover:stroke-Text-text-button-hover" />
          </a>
        </div>

        <div class="dropdown-divider my-2"></div>
      <% end %>

      <%= if @account_locked do %>
        <.button
          variant={:warning}
          class="mt-1"
          phx-click="show_unlock_account_modal"
          phx-value-id={@user_id}
        >
          Unlock Account
        </.button>
      <% else %>
        <.button
          variant={:warning}
          class="mt-1"
          phx-click="show_lock_account_modal"
          phx-value-id={@user_id}
        >
          Lock Account
        </.button>
      <% end %>

      <div class="dropdown-divider my-2"></div>

      <.button
        variant={:danger}
        class="mt-4"
        phx-click="show_delete_account_modal"
        phx-value-id={@user_id}
      >
        Delete Account
      </.button>
    </div>
    """
  end
end
