defmodule OliWeb.Users.Actions do
  use Surface.Component

  alias Oli.Accounts
  alias Oli.Accounts.SystemRole
  alias OliWeb.Router.Helpers, as: Routes

  prop for_author, :boolean, default: false
  prop user, :any, required: true
  prop csrf_token, :any, required: true

  def render(assigns) do
    {resend, reset} =
      case assigns.for_author do
        true -> {:resend_author_confirmation_link, :send_author_password_reset_link}
        false -> {:resend_user_confirmation_link, :send_user_password_reset_link}
      end

    resend_confirmation_link_path = Routes.pow_path(OliWeb.Endpoint, resend)
    reset_password_link_path = Routes.pow_path(OliWeb.Endpoint, reset)

    ~F"""
    <div>
      <form id={"resend-confirmation-#{@user.id}"} method="post" action={resend_confirmation_link_path}>
        <input type="hidden" name="_csrf_token" value={@csrf_token}>
        <input type="hidden" name="id" value={@user.id}>
      </form>
      <form id={"reset-password-#{@user.id}"} method="post" action={reset_password_link_path}>
        <input type="hidden" name="_csrf_token" value={@csrf_token}>
        <input type="hidden" name="id" value={@user.id}>
      </form>

      {#if Accounts.user_confirmation_pending?(@user)}
        <button type="submit" class="btn btn-primary" form={"resend-confirmation-#{@user.id}"}>Resend confirmation link</button>
        <button class="btn btn-primary" phx-click="show_confirm_email_modal" phx-value-id={@user.id}>Confirm email</button>

        <div class="dropdown-divider" />
      {/if}

      {#if @for_author}
        {#if @user.system_role_id == SystemRole.role_id().admin}
          <button class="btn btn-warning" phx-click="show_revoke_admin_modal" phx-value-id={@user.id}>Revoke admin</button>
        {#else}
          <button class="btn btn-warning" phx-click="show_grant_admin_modal" phx-value-id={@user.id}>Grant admin</button>
        {/if}
        <div class="dropdown-divider" />
      {/if}

      <button type="submit" class="btn btn-primary" form={"reset-password-#{@user.id}"}>Send password reset link</button>

      <div class="dropdown-divider" />

      {#if !is_nil(@user.locked_at)}
        <button class="btn btn-warning" phx-click="show_unlock_account_modal" phx-value-id={@user.id}>Unlock Account</button>
      {#else}
        <button class="btn btn-warning" phx-click="show_lock_account_modal" phx-value-id={@user.id}>Lock Account</button>
      {/if}

      <div class="dropdown-divider" />

      <button class="btn btn-danger" phx-click="show_delete_account_modal" phx-value-id={@user.id}>Delete Account</button>
    </div>
    """
  end
end
