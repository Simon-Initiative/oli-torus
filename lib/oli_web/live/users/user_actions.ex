defmodule OliWeb.Users.Actions do
  use Surface.Component

  alias OliWeb.Router.Helpers, as: Routes

  prop user, :any, required: true
  prop csrf_token, :any, required: true

  def render(assigns) do
    resend_confirmation_link_path =
      Routes.pow_path(OliWeb.Endpoint, :resend_user_confirmation_link)

    reset_password_link_path = Routes.pow_path(OliWeb.Endpoint, :send_user_password_reset_link)

    if assigns.user.independent_learner do
      ~F"""
        <div>
          <form id={"resend-confirmation-#{@user.id}"} method="post" action={resend_confirmation_link_path}>
            <input type="hidden" name="_csrf_token" value={@csrf_token} />
            <input type="hidden" name="id" value={@user.id} />
          </form>
          <form id={"reset-password-#{@user.id}"} method="post" action={reset_password_link_path}>
            <input type="hidden" name="_csrf_token" value={@csrf_token} />
            <input type="hidden" name="id" value={@user.id} />
          </form>

          {#if is_nil(@user.email_confirmed_at)}
            <button type="submit" class="btn btn-primary" form={"resend-confirmation-#{@user.id}"}>Resend confirmation link</button>
            <button class="btn btn-primary" phx-click="show_confirm_email_modal" phx-value-id={@user.id}>Confirm email</button>

            <div class="dropdown-divider"></div>
          {/if}

          <button type="submit" class="btn btn-primary" form={"reset-password-#{@user.id}"}>Send password reset link</button>

          <div class="dropdown-divider"></div>

          {#if !is_nil(@user.locked_at)}
            <button class="btn btn-warning" phx-click="show_unlock_account_modal" phx-value-id={@user.id}>Unlock Account</button>
          {#else}

            <button class="btn btn-warning" phx-click="show_lock_account_modal" phx-value-id={@user.id}>Lock Account</button>
          {/if}

          <div class="dropdown-divider"></div>

          <button class="btn btn-danger" phx-click="show_delete_account_modal" phx-value-id={@user.id}>Delete Account</button>
       </div>
      """
    else
      ~L"""
      <div></div>
      """
    end
  end
end
