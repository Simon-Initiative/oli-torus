defmodule OliWeb.Users.Actions do
  use OliWeb, :html

  alias OliWeb.Common.Properties.ReadOnly
  alias OliWeb.Icons

  attr(:user_id, :integer, required: true)
  attr(:account_locked, :boolean, required: true)
  attr(:email_confirmation_pending, :boolean, required: true)
  attr(:password_reset_link, :string, default: "")
  slot(:pending_invitations)

  def render(assigns) do
    ~H"""
    <div>
      <div class="form-group !mb-2">
        <.button
          variant={:link}
          size={nil}
          class="group inline-flex min-h-11 items-center gap-1 p-0 text-sm font-semibold leading-4"
          phx-click="generate_reset_password_link"
          phx-value-id={@user_id}
        >
          <i class="fa-solid fa-key text-xs"></i> Generate Reset Password Link
        </.button>

        <div class="mt-2">
          <ReadOnly.render
            label=""
            show_copy_btn={true}
            value={@password_reset_link}
            class="!mb-0"
            copy_style={:abutted}
            input_class="!h-[26px] !bg-Surface-surface-primary !border-Border-border-default !py-0"
            button_class="!h-[26px] !border-Border-border-default !py-0 !px-2"
          />
        </div>
      </div>

      <div :if={@pending_invitations != []} class="mt-2">
        {render_slot(@pending_invitations)}
      </div>

      <%= if @email_confirmation_pending do %>
        <.button
          variant={:primary}
          size={:xs}
          class="mt-4 mr-1"
          phx-click="resend_confirmation_link"
          phx-value-id={@user_id}
        >
          Resend confirmation link
        </.button>
        <.button
          variant={:primary}
          size={:xs}
          phx-click="show_confirm_email_modal"
          phx-value-id={@user_id}
        >
          Confirm email
        </.button>

        <div class="h-2"></div>
      <% else %>
        <div class="mt-0.5">
          <.button
            variant={:link}
            size={nil}
            class="group inline-flex min-h-11 items-center gap-1 p-0 text-sm font-semibold leading-4"
            phx-click="send_reset_password_link"
            phx-value-id={@user_id}
          >
            Send password reset link
            <Icons.send class="stroke-Text-text-button group-hover:stroke-Text-text-button-hover" />
          </.button>
        </div>
        <p :if={@password_reset_link not in [nil, ""]} class="mt-1 mb-1">
          This link will expire in 24 hours.
        </p>

        <div class="h-12"></div>
      <% end %>

      <div class="flex flex-col items-start gap-2">
        <%= if @account_locked do %>
          <.button
            variant={:outline}
            size={:xs}
            class="min-w-[113px] !border-Specially-Tokens-Icon-icon-tile-tag-orange !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
            phx-click="show_unlock_account_modal"
            phx-value-id={@user_id}
          >
            Unlock Account
          </.button>
        <% else %>
          <.button
            variant={:outline}
            size={:xs}
            class="min-w-[113px] !border-Specially-Tokens-Icon-icon-tile-tag-orange !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
            phx-click="show_lock_account_modal"
            phx-value-id={@user_id}
          >
            Lock Account
          </.button>
        <% end %>

        <.button
          variant={:outline}
          size={:xs}
          class="min-w-[113px] !border-Border-border-danger !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
          phx-click="show_delete_account_modal"
          phx-value-id={@user_id}
        >
          Delete Account
        </.button>
      </div>
    </div>
    """
  end
end
