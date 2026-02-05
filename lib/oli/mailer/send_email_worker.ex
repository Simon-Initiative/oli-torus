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
      "reply_to" => serialize_reply_to(email.reply_to),
      "subject" => email.subject,
      "html_body" => email.html_body,
      "text_body" => email.text_body,
      "headers" => email.headers
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

    reply_to = Map.get(args, "reply_to")
    headers = Map.get(args, "headers", %{})

    opts = [
      to: deserialize_address(to),
      from: deserialize_address(from),
      subject: subject,
      html_body: html_body,
      text_body: text_body,
      headers: headers
    ]

    opts
    |> Swoosh.Email.new()
    |> maybe_set_reply_to(reply_to)
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

  # reply_to can be a single address or a list, but Swoosh stores it as a single value
  defp serialize_reply_to(nil), do: nil
  defp serialize_reply_to({name, email}), do: %{"name" => name, "email" => email}
  defp serialize_reply_to(email) when is_binary(email), do: email

  defp maybe_set_reply_to(email, nil), do: email

  defp maybe_set_reply_to(email, %{"name" => name, "email" => addr}),
    do: Swoosh.Email.reply_to(email, {name, addr})

  defp maybe_set_reply_to(email, reply_to) when is_binary(reply_to),
    do: Swoosh.Email.reply_to(email, reply_to)
end
