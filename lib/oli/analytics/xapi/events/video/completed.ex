defmodule Oli.Analytics.XAPI.Events.Video.Completed do
  alias Oli.Analytics.XAPI.Events.Context

  def new(
        %Context{
          user_id: user_id,
          host_name: host_name,
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id
        },
        %{
          attempt_guid: page_attempt_guid,
          attempt_number: page_attempt_number,
          resource_id: page_id,
          timestamp: timestamp,
          video_url: video_url,
          video_title: video_title,
          video_length: video_length,
          video_played_segments: video_played_segments,
          video_progress: video_progress,
          video_time: video_time,
          content_element_id: content_element_id
        }
      ) do
    %{
      "actor" => %{
        "account" => %{
          "homePage" => host_name,
          "name" => user_id
        },
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "https://w3id.org/xapi/video/verbs/completed",
        "display" => %{
          "en-US" => "completed"
        }
      },
      "object" => %{
        "id" => video_url,
        "definition" => %{
          "name" => %{
            "en-US" => video_title
          },
          "type" => "https://w3id.org/xapi/video/activity-type/video"
        },
        "objectType" => "Activity"
      },
      "result" => %{
        "extensions" => %{
          "https://w3id.org/xapi/video/extensions/played-segments" => video_played_segments,
          "https://w3id.org/xapi/video/extensions/progress" => video_progress,
          "https://w3id.org/xapi/video/extensions/time" => video_time
        }
      },
      "context" => %{
        "contextActivities" => %{
          "category" => [%{"id" => "https://w3id.org/xapi/video"}]
        },
        "extensions" => %{
          "http://oli.cmu.edu/extensions/page_attempt_number" => page_attempt_number,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => page_attempt_guid,
          "http://oli.cmu.edu/extensions/section_id" => section_id,
          "http://oli.cmu.edu/extensions/project_id" => project_id,
          "http://oli.cmu.edu/extensions/publication_id" => publication_id,
          "http://oli.cmu.edu/extensions/resource_id" => page_id,
          "http://oli.cmu.edu/extensions/content_element_id" => content_element_id,
          "https://w3id.org/xapi/video/extensions/completion-threshold" => "1.0",
          "https://w3id.org/xapi/video/extensions/length" => video_length
        }
      },
      "timestamp" => timestamp,
      "registration" => "#{section_id}-#{page_id}-#{content_element_id}"
    }
  end
end
