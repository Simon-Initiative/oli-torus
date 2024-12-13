defmodule Oli.Mailer.SendEmailWorker do
  use Oban.Worker, queue: :mailer

  alias Oli.Mailer

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"email" => email_args}}) do
    with email <- deserialize_email(email_args),
         {:ok, _metadata} <- Mailer.deliver(email) do
      :ok
    end
  end

  def serialize_email(%Swoosh.Email{} = email) do
    %{
      "to" => serialize_address(email.to),
      "from" => serialize_address(email.from),
      "subject" => email.subject,
      "html_body" => email.html_body,
      "text_body" => email.text_body
    }
  end

  def deserialize_email(args) do
    %{
      "to" => to,
      "from" => from,
      "subject" => subject,
      "html_body" => html_body,
      "text_body" => text_body
    } = args

    opts = [
      to: deserialize_address(to),
      from: deserialize_address(from),
      subject: subject,
      html_body: html_body,
      text_body: text_body
    ]

    Swoosh.Email.new(opts)
  end

  defp serialize_address(addresses) when is_list(addresses) do
    Enum.map(addresses, &serialize_address/1)
  end

  defp serialize_address({name, email}) do
    %{"name" => name, "email" => email}
  end

  defp deserialize_address(addresses) when is_list(addresses) do
    Enum.map(addresses, &deserialize_address/1)
  end

  defp deserialize_address(%{"name" => name, "email" => email}) do
    {name, email}
  end
end
