defmodule OliWeb.PowInvitation.MailerView do
  use OliWeb, :mailer_view

  def subject(:invitation_new_user, _assigns), do: "You've been invited"

  def subject(:invitation_existing_user, _assigns), do: "You've been invited"
end
