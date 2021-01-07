defmodule Oli.Slack do
  require Logger

  @doc """
  Sends a message to slack using the pre-configured configured webhook

  Example Payload:
  %{
    "username" => "webhookbot",
    "channel" => "#general",
    "text" => "This is posted to #general and comes from a bot named webhookbot. <http://url_to_task|Click here>.",
    "icon_emoji" => ":robot_face:",
  }
  """
  def send(payload) do
    case Application.fetch_env(:oli, :slack_webhook_url) do
      {:ok, slack_webhook_url} ->
        HTTPoison.post(
          slack_webhook_url,
          Jason.encode!(payload),
          [{"Content-Type", "application/json"}]
        )

      :error ->
        Logger.warning("This message cannot be sent because SLACK_WEBHOOK_URL is not configured", payload)

        {:error, "SLACK_WEBHOOK_URL not configured"}
    end
  end
end
