defmodule Oli.SlackTest do
  use Oli.DataCase

  import Mox
  import ExUnit.CaptureLog

  alias Oli.Test.MockHTTP
  alias Oli.Slack

  @slack_webhook_url "https://hooks.example.com/services/ASDF7ASDF7ASH/ASDF7HQ9JF3/0JR43098o78hdfsdf"

  defp setup_slack_webhook_url_env(_) do
    Application.put_env(:oli, :slack_webhook_url, @slack_webhook_url)
  end

  defp remove_slack_webhook_url_env_on_exit(_) do
    on_exit(fn -> Application.put_env(:oli, :slack_webhook_url, nil) end)
  end

  describe "slack messaging properly configured" do
    # Make sure mocks are verified when the test exits
    setup [:verify_on_exit!, :setup_slack_webhook_url_env, :remove_slack_webhook_url_env_on_exit]

    test "sends a slack message to the configured url" do
      payload = get_example_payload()
      body = payload |> Jason.encode!()
      slack_webhook_url = @slack_webhook_url

      MockHTTP
      |> expect(:post, fn ^slack_webhook_url, ^body, _headers ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "OK"}}
      end)

      assert Slack.send(payload) == {:ok, %HTTPoison.Response{status_code: 200, body: "OK"}}
    end
  end

  describe "slack messaging not configured" do
    test "fails and logs a warning that slack_webhook_url is not configured" do
      payload = get_example_payload()

      assert capture_log(fn ->
               assert Slack.send(payload) == {:error, "SLACK_WEBHOOK_URL not configured"}
             end) =~ "This message cannot be sent because SLACK_WEBHOOK_URL is not configured"
    end
  end

  defp get_example_payload() do
    %{
      "blocks" => [
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "Chew choo! @scott started a train to Deli Board at 11:30. Will you join?"
          }
        },
        %{
          "type" => "actions",
          "elements" => [
            %{
              "type" => "button",
              "text" => %{
                "type" => "plain_text",
                "text" => "Yes",
                "emoji" => true
              }
            },
            %{
              "type" => "button",
              "text" => %{
                "type" => "plain_text",
                "text" => "No",
                "emoji" => true
              }
            }
          ]
        }
      ]
    }
  end
end
