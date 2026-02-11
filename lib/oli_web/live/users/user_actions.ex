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
      <div class="form-group !mb-2">
        <.button
          variant={:primary}
          size={:sm}
          class="inline-flex items-center justify-center !bg-Fill-Buttons-fill-primary hover:!bg-Fill-Buttons-fill-primary-hover"
          phx-click="generate_reset_password_link"
          phx-value-id={@user_id}
        >
          Generate Reset Password Link
        </.button>

        <div class="mt-2">
          <ReadOnly.render
            label=""
            show_copy_btn={true}
            value={@password_reset_link}
            class="!mb-0"
            copy_style={:abutted}
            input_class="!bg-Surface-surface-primary !border-Border-border-default"
            button_class="!border-Border-border-default"
          />
        </div>
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

        <div class="h-12"></div>
      <% else %>
        <div class="mt-0.5">
          <.button
            variant={:link}
            size={nil}
            class="group inline-flex items-center gap-1 p-0 text-sm font-semibold leading-4"
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

      <div class="flex flex-col items-start gap-3">
        <%= if @account_locked do %>
          <.button
            variant={:outline}
            size={:sm}
            class="w-[160px] !border-Specially-Tokens-Icon-icon-tile-tag-orange !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
            phx-click="show_unlock_account_modal"
            phx-value-id={@user_id}
          >
            Unlock Account
          </.button>
        <% else %>
          <.button
            variant={:outline}
            size={:sm}
            class="w-[160px] !border-Specially-Tokens-Icon-icon-tile-tag-orange !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
            phx-click="show_lock_account_modal"
            phx-value-id={@user_id}
          >
            Lock Account
          </.button>
        <% end %>

        <.button
          variant={:outline}
          size={:sm}
          class="w-[160px] !border-Border-border-danger !text-Specially-Tokens-Text-text-button-pill-muted shadow-[0px_2px_4px_0px_rgba(0,52,99,0.10)]"
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
