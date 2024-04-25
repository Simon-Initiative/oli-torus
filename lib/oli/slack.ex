defmodule Oli.Slack do
  require Logger

  import Oli.HTTP

  @doc """
  Sends a message to slack using the pre-configured configured webhook

  Example Payload:
  %{
    "blocks" => [
      {
        "type" => "section",
        "text" => {
          "type" => "mrkdwn",
          "text" => "Chew choo! @scott started a train to Deli Board at 11:30. Will you join?"
        }
      },
      {
        "type" => "actions",
        "elements" => [
          {
            "type" => "button",
            "text" => {
              "type" => "plain_text",
              "text" => "Yes",
              "emoji" => true
            }
          },
          {
            "type" => "button",
            "text" => {
              "type" => "plain_text",
              "text" => "No",
              "emoji"=> true
            }
          }
        ]
      }
    ]
  }
  """
  def send(payload) do
    case Application.fetch_env!(:oli, :slack_webhook_url) do
      nil ->
        Logger.warning(
          "This message cannot be sent because SLACK_WEBHOOK_URL is not configured",
          payload
        )

        {:error, "SLACK_WEBHOOK_URL not configured"}

      slack_webhook_url ->
        case http().post(
               slack_webhook_url,
               Jason.encode!(payload),
               [{"Content-Type", "application/json"}]
             ) do
          {:ok, %{status_code: 200, body: result}} ->
            result

          e ->
            Oli.Utils.Appsignal.capture_error(e)
            Logger.error("Could not send message to Slack")
            e
        end
    end
  end
end
