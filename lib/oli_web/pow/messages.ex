defmodule OliWeb.Pow.Messages do
  @moduledoc """
  Custom module that handles returned messages by pow actions.
  """
  use Pow.Phoenix.Messages

  use Pow.Extension.Phoenix.Messages,
    extensions: [
      PowAssent,
      PowResetPassword,
      PowEmailConfirmation,
      PowPersistentSession,
      PowInvitation
    ]

  alias Oli.Accounts
  alias OliWeb.Router.Helpers, as: Routes
  alias Phoenix.HTML.Link
  alias Pow.Phoenix.Messages

  @before_signin_message """
    We have detected an account using that email was previously created when you accessed the system from your LMS.
    For your scores to count toward your course, you must return to your LMS and continue access from there.
    If you wish to create a new account independent of that course
  """

  def invalid_credentials(conn) do
    message = [
      @before_signin_message,
      ", ",
      Link.link("Create an Account", to: Routes.pow_registration_path(conn, :new)),
      "."
    ]

    if Accounts.is_lms_user?(conn.params["user"]["email"]) do
      message
    else
      Messages.invalid_credentials(conn)
    end
  end

  @doc """
  Flash message to show when user registers but e-mail is yet to be confirmed.
  """
  def pow_email_confirmation_email_confirmation_required(conn) do
    email = conn.params["user"]["email"]

    """
    To continue, check #{email} for a confirmation email.\n
    If you don’t receive this email, check your Spam folder or verify that #{email} is correct.\n
    You can close this tab if you received the email.
    """
  end
end
