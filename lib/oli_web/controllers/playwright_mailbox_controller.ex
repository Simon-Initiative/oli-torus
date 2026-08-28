defmodule OliWeb.PlaywrightMailboxController do
  @moduledoc """
  Token-protected access to messages captured by `Swoosh.Adapters.Local`.

  These routes are mounted only in Playwright-enabled builds. They provide a
  stable JSON contract for browser tests without exposing or automating the
  development mailbox preview UI.
  """

  use OliWeb, :controller

  alias OliWeb.PlaywrightAuth
  alias Swoosh.Adapters.Local.Storage.Memory

  def index(conn, params) do
    with :ok <- PlaywrightAuth.authorize(conn),
         {:ok, recipient} <- fetch_recipient(params) do
      subject = Map.get(params, "subject")

      emails =
        Memory.all()
        |> Enum.filter(&sent_to?(&1, recipient))
        |> maybe_filter_subject(subject)
        |> Enum.map(&email_summary/1)

      json(conn, %{emails: emails})
    else
      {:error, :unauthorized} -> send_resp(conn, :unauthorized, "unauthorized")
      {:error, :missing_recipient} -> send_resp(conn, :bad_request, "missing_recipient")
    end
  end

  def show(conn, %{"id" => id}) do
    with :ok <- PlaywrightAuth.authorize(conn),
         %Swoosh.Email{} = email <- Memory.get(id) do
      json(conn, %{email: email_detail(email)})
    else
      {:error, :unauthorized} -> send_resp(conn, :unauthorized, "unauthorized")
      nil -> send_resp(conn, :not_found, "not_found")
    end
  end

  defp fetch_recipient(%{"to" => recipient}) when is_binary(recipient) and recipient != "",
    do: {:ok, recipient}

  defp fetch_recipient(_), do: {:error, :missing_recipient}

  defp sent_to?(email, recipient) do
    Enum.any?(email.to, &(recipient_address(&1) == recipient))
  end

  defp recipient_address({_name, address}), do: address
  defp recipient_address(address) when is_binary(address), do: address

  defp maybe_filter_subject(emails, subject) when is_binary(subject) and subject != "" do
    Enum.filter(emails, &(&1.subject == subject))
  end

  defp maybe_filter_subject(emails, _subject), do: emails

  defp email_summary(email) do
    %{
      id: message_id(email),
      to: Enum.map(email.to, &recipient_address/1),
      subject: email.subject,
      sent_at: Map.get(email.private, :sent_at)
    }
  end

  defp email_detail(email) do
    email
    |> email_summary()
    |> Map.merge(%{html_body: email.html_body, text_body: email.text_body})
  end

  defp message_id(%{headers: %{"Message-ID" => id}}), do: id
end
