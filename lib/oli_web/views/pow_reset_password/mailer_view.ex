defmodule OliWeb.PowResetPassword.MailerView do
  use OliWeb, :mailer_view

  def subject(:reset_password, _assigns), do: "Reset password link"
end
