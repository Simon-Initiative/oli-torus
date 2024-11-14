defmodule Oli.Mailer do
  use Swoosh.Mailer, otp_app: :oli

  alias Oli.Mailer.SendEmailWorker

  def deliver_later(email) do
    %{email: SendEmailWorker.serialize_email(email)}
    |> SendEmailWorker.new()
    |> Oban.insert()

    {:ok, email}
  end
end
