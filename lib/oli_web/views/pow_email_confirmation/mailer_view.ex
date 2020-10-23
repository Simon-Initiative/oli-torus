defmodule OliWeb.PowEmailConfirmation.MailerView do
  use OliWeb, :mailer_view

  def subject(:email_confirmation, _assigns), do: "Confirm your email address"
end
