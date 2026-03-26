defmodule Oli.Delivery.EmailSender do
  @moduledoc """
  Shared email delivery helpers for instructor-facing delivery workflows.
  """

  alias Oli.Mailer

  @spec normalize_recipient_emails([String.t() | nil]) :: [String.t()]
  def normalize_recipient_emails(recipient_emails) do
    recipient_emails
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  @spec deliver_text_emails(
          [String.t() | nil],
          String.t(),
          String.t(),
          String.t() | nil,
          String.t() | nil
        ) ::
          {:ok, non_neg_integer()} | {:error, term()}
  def deliver_text_emails(recipient_emails, subject, body, instructor_email, instructor_name) do
    recipient_emails = normalize_recipient_emails(recipient_emails)
    email_count = length(recipient_emails)

    emails =
      recipient_emails
      |> Enum.map(fn recipient_email ->
        Oli.Email.create_text_email(recipient_email, subject, body)
        # Note: We don't set FROM to instructor's email because email providers like
        # Amazon SES require verified sender addresses. The reply_to header ensures
        # replies go back to the instructor.
        |> Oli.Email.maybe_reply_to(reply_to_value(instructor_name, instructor_email))
      end)

    case Mailer.deliver_later(emails) do
      jobs when is_list(jobs) ->
        {:ok, email_count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reply_to_value(_name, nil), do: nil
  defp reply_to_value(_name, ""), do: nil
  defp reply_to_value(nil, email), do: email
  defp reply_to_value("", email), do: email
  defp reply_to_value(name, email), do: {name, email}
end
