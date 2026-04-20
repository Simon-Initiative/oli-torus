defmodule Oli.InstructorDashboard.Recommendations.FeedbackSlack do
  @moduledoc """
  Formats Slack notifications for instructor recommendation feedback.
  """

  @spec payload(map()) :: map()
  def payload(attrs) when is_map(attrs) do
    username = Map.get(attrs, :username, "Torus Bot")
    section_title = Map.get(attrs, :section_title, "Unknown Section")
    section_slug = Map.get(attrs, :section_slug, "")
    scope_label = Map.get(attrs, :scope_label, "Selected Scope")
    recommendation_id = Map.get(attrs, :recommendation_id, "Unknown")
    submitted_by = Map.get(attrs, :submitted_by, "Unknown")
    recommendation_text = Map.get(attrs, :recommendation_text, "")
    feedback_text = Map.get(attrs, :feedback_text, "")

    sentiment_text =
      case Map.get(attrs, :sentiment) do
        :thumbs_up -> "👍"
        :thumbs_down -> "👎"
        value when is_binary(value) and value != "" -> value
        _ -> "Not provided"
      end

    %{
      "username" => username,
      "icon_emoji" => ":robot_face:",
      "blocks" => [
        %{
          "type" => "header",
          "text" => %{
            "type" => "plain_text",
            "text" => "🤖 AI Recommendation Feedback"
          }
        },
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" =>
              "Additional AI recommendation feedback received for *#{section_title}* (#{section_slug})."
          }
        },
        %{
          "type" => "section",
          "fields" => [
            %{"type" => "mrkdwn", "text" => "*Scope:*\n#{scope_label}"},
            %{
              "type" => "mrkdwn",
              "text" => "*Recommendation ID:*\n#{recommendation_id}"
            }
          ]
        },
        %{
          "type" => "section",
          "fields" => [
            %{"type" => "mrkdwn", "text" => "*Submitted by:*\n#{submitted_by}"},
            %{"type" => "mrkdwn", "text" => "*Sentiment:*\n#{sentiment_text}"}
          ]
        },
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "*Recommendation:*\n#{recommendation_text}"
          }
        },
        %{
          "type" => "section",
          "text" => %{
            "type" => "mrkdwn",
            "text" => "*Additional feedback:*\n#{feedback_text}"
          }
        }
      ]
    }
  end
end
