defmodule Oli.InstructorDashboard.Recommendations.FeedbackSlack do
  @moduledoc """
  Formats Slack notifications for instructor recommendation feedback.

  Privacy note: this payload is intentionally generic and must not include
  user, section, recommendation, or feedback details.
  """

  @spec payload(map()) :: map()
  def payload(_attrs) do
    %{
      "username" => "Torus Bot",
      "icon_emoji" => ":robot_face:",
      "blocks" => [
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "A new custom feedback has been captured."
          }
        }
      ]
    }
  end
end
