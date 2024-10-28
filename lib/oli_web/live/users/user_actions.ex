defmodule OliWeb.Users.Actions do
  use OliWeb, :html

  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes

  attr(:for_author, :boolean, default: false)
  attr(:user, :any, required: true)
  attr(:csrf_token, :any, required: true)
  attr(:password_reset_link, :string, default: "")

  def user_actions(assigns) do
    {resend, reset} =
      case assigns.for_author do
        true -> {:resend_author_confirmation_link, :send_author_password_reset_link}
        false -> {:resend_user_confirmation_link, :send_user_password_reset_link}
      end

    resend_confirmation_link_path = Routes.pow_path(OliWeb.Endpoint, resend)
    reset_password_link_path = Routes.pow_path(OliWeb.Endpoint, reset)

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
          This link will expire in 24 hours.
        </p>
        <button
          phx-click="generate_reset_password_link"
          phx-value-id={@user.id}
          class="btn btn-md btn-primary my-1"
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
        <button type="submit" class="btn btn-primary my-1" form={"resend-confirmation-#{@user.id}"}>
          Resend confirmation link
        </button>
        <button
          class="btn btn-primary my-1"
          phx-click="show_confirm_email_modal"
          phx-value-id={@user.id}
        >
          Confirm email
        </button>

        <div class="dropdown-divider"></div>
      <% end %>

      <button type="submit" class="btn btn-primary my-1" form={"reset-password-#{@user.id}"}>
        Send password reset link
      </button>

      <div class="dropdown-divider"></div>

      <%= if !is_nil(@user.locked_at) do %>
        <button
          class="btn btn-warning my-1"
          phx-click="show_unlock_account_modal"
          phx-value-id={@user.id}
        >
          Unlock Account
        </button>
      <% else %>
        <button
          class="btn btn-warning my-1"
          phx-click="show_lock_account_modal"
          phx-value-id={@user.id}
        >
          Lock Account
        </button>
      <% end %>

      <%= unless @for_author do %>
        <div class="dropdown-divider"></div>

        <button class="btn btn-warning my-1" phx-click="act_as_user" phx-value-id={@user.id}>
          Act as User
        </button>
      <% end %>

      <div class="dropdown-divider"></div>

      <button
        class="btn btn-danger my-6"
        phx-click="show_delete_account_modal"
        phx-value-id={@user.id}
      >
        Delete Account
      </button>
    </div>
    """
  end

  def lti_user_actions(assigns) do
    ~H"""
    <div>
      <div class="text-secondary my-4">LTI users are managed by their LMS</div>
      <div>
        <button class="btn btn-warning" phx-click="act_as_user" phx-value-id={@user.id}>
          Act as User
        </button>
      </div>
    </div>
    """
  end
end
