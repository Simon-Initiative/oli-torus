defmodule OliWeb.Users.Actions do
  use OliWeb, :html

  alias Oli.Accounts

  attr(:for_author, :boolean, default: false)
  attr(:user, :any, required: true)
  attr(:csrf_token, :any, required: true)
  attr(:password_reset_link, :string, default: "")

  def render(assigns) do
    {resend, reset} =
      case assigns.for_author do
        true -> {:resend_author_confirmation_link, :send_author_password_reset_link}
        false -> {:resend_user_confirmation_link, :send_user_password_reset_link}
      end

    # MER-3835 TODO
    throw "NOT IMPLEMENTED"
    resend_confirmation_link_path = ~p"/"
    reset_password_link_path = ~p"/"

    assigns =
      assign(assigns,
        resend_confirmation_link_path: resend_confirmation_link_path,
        reset_password_link_path: reset_password_link_path
      )

    ~H"""
    <div>
      <div class="form-group">
        <label for="reset_link_input">Generate Reset Password Link</label>
        <div class="input-group" style="max-width: 100%;">
          <input
            readonly
            type="text"
            id="password-reset-link-1"
            class="form-control"
            aria-label="Password Reset Link Text Input"
            value={@password_reset_link}
          />
          <div class="input-group-append">
            <button
              id="copy-password-reset-link-button"
              class="btn btn-outline-secondary"
              data-clipboard-target="#password-reset-link-1"
              phx-hook="CopyListener"
            >
              <i class="far fa-clipboard"></i> Copy
            </button>
          </div>
        </div>

        <p :if={@password_reset_link not in [nil, ""]} class="mb-1">
          This link will expired in 24 hours.
        </p>
        <button
          phx-click="generate_reset_password_link"
          phx-value-id={@user.id}
          class="btn btn-md btn-primary"
        >
          Generate
        </button>
      </div>

      <form
        id={"resend-confirmation-#{@user.id}"}
        method="post"
        action={@resend_confirmation_link_path}
      >
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <input type="hidden" name="user_id" value={@user.id} />
      </form>
      <form id={"reset-password-#{@user.id}"} method="post" action={@reset_password_link_path}>
        <input type="hidden" name="_csrf_token" value={@csrf_token} />
        <input type="hidden" name="user_id" value={@user.id} />
      </form>

      <%= if Accounts.user_confirmation_pending?(@user) do %>
        <button type="submit" class="btn btn-primary" form={"resend-confirmation-#{@user.id}"}>
          Resend confirmation link
        </button>
        <button class="btn btn-primary" phx-click="show_confirm_email_modal" phx-value-id={@user.id}>
          Confirm email
        </button>

        <div class="dropdown-divider"></div>
      <% end %>

      <button type="submit" class="btn btn-primary" form={"reset-password-#{@user.id}"}>
        Send password reset link
      </button>

      <div class="dropdown-divider"></div>

      <%= if !is_nil(@user.locked_at) do %>
        <button class="btn btn-warning" phx-click="show_unlock_account_modal" phx-value-id={@user.id}>
          Unlock Account
        </button>
      <% else %>
        <button class="btn btn-warning" phx-click="show_lock_account_modal" phx-value-id={@user.id}>
          Lock Account
        </button>
      <% end %>

      <div class="dropdown-divider"></div>

      <button class="btn btn-danger" phx-click="show_delete_account_modal" phx-value-id={@user.id}>
        Delete Account
      </button>
    </div>
    """
  end
end
