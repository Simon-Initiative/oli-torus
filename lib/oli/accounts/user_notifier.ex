defmodule Oli.Accounts.UserNotifier do
  alias Oli.{Email, Mailer}

  defp send_email(email, subject, view, assigns) do
    # Email delivery should be processed asynchronously here to prevent enumeration
    # attacks. Synchronous e-mail delivery can reveal whether a user already
    # exists in the system or not.
    Email.create_email(
      email,
      subject,
      view,
      assigns
    )
    |> Mailer.deliver_later()
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(user, url) do
    send_email(
      user.email,
      "Confirm your email",
      :email_confirmation,
      %{
        url: url
      }
    )
  end

  @doc """
  Deliver instructions to reset a user password.
  """
  def deliver_reset_password_instructions(user, url) do
    send_email(
      user.email,
      "Reset password",
      :reset_password,
      %{
        url: url
      }
    )
  end
end
