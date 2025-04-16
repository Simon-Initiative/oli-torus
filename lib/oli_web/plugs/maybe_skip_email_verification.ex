defmodule OliWeb.Plugs.MaybeSkipEmailVerification do
  @moduledoc """
  This plug assigns the `skip_email_verification` key to the connection if the user is enrolled in a
  section that skips email verification.

  A database request to check if the user is enrolled in any section which omits email verification
  is only made if the user has not confirmed their email.

  This assign is used by the `OliWeb.UserAuth` plug to bypass normally required email verification
  check.
  """
  import Plug.Conn

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  def init(default), do: default

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %User{email_confirmed_at: nil} = user ->
        conn
        |> assign(
          :skip_email_verification,
          Sections.user_enrolled_in_section_that_skips_email_confirmation?(user)
        )

      _ ->
        conn
    end
  end
end
