defmodule Oli.Analytics.XAPI.Events.Attempt.TutorMessage do
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Delivery.Attempts.Core.ActivityAttempt

  def new(
        %Context{
          user_id: user_id,
          host_name: host_name,
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id
        },
        %ActivityAttempt{
          attempt_guid: attempt_guid,
          attempt_number: attempt_number,
          resource_id: activity_id,
          revision_id: activity_revision_id
        },
        %{
          attempt_guid: page_attempt_guid,
          attempt_number: page_attempt_number,
          resource_id: page_id,
          message: message,
          timestamp: timestamp
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
        "id" => "http://activitystrea.ms/schema/1.0/create",
        "display" => %{
          "en-US" => "created"
        }
      },
      "object" => %{
        "id" => "#{host_name}/tutor_message/#{attempt_guid}",
        "definition" => %{
          "name" => %{
            "en-US" => "Tutor Message"
          },
          "type" => "http://oli.cmu.edu/extensions/tutor_message"
        },
        "objectType" => "Tutor"
      },
      "result" => %{
        "message" => message
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/activity_attempt_number" => attempt_number,
          "http://oli.cmu.edu/extensions/page_attempt_number" => page_attempt_number,
          "http://oli.cmu.edu/extensions/activity_attempt_guid" => attempt_guid,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => page_attempt_guid,
          "http://oli.cmu.edu/extensions/section_id" => section_id,
          "http://oli.cmu.edu/extensions/project_id" => project_id,
          "http://oli.cmu.edu/extensions/publication_id" => publication_id,
          "http://oli.cmu.edu/extensions/page_id" => page_id,
          "http://oli.cmu.edu/extensions/activity_id" => activity_id,
          "http://oli.cmu.edu/extensions/activity_revision_id" => activity_revision_id
        }
      },
      "timestamp" => timestamp
    }
  end
end
