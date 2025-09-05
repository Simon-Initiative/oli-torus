defmodule Oli.Mailer do
  use Swoosh.Mailer, otp_app: :oli

  alias Oli.Mailer.SendEmailWorker

  def deliver_later(emails) when is_list(emails) do
    emails
    |> Enum.map(fn email ->
      SendEmailWorker.new(%{email: SendEmailWorker.serialize_email(email)})
    end)
    |> Oban.insert_all()
  end

  def deliver_later(email) do
    %{email: SendEmailWorker.serialize_email(email)}
    |> SendEmailWorker.new()
    |> Oban.insert()

    {:ok, email}
  end
end
