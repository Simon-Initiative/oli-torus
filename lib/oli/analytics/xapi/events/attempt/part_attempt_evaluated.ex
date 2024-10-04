defmodule Oli.Analytics.XAPI.Events.Attempt.PartAttemptEvaluated do
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
          activity_revision: activity_revision,
          activity_attempt: activity_attempt,
          attempt_guid: part_attempt_guid,
          attempt_number: part_attempt_number,
          hints: hints,
          response: response,
          score: score,
          out_of: out_of,
          feedback: feedback,
          date_evaluated: timestamp,
          part_id: part_id,
          datashop_session_id: session_id
        },
        %{
          attempt_guid: page_attempt_guid,
          attempt_number: page_attempt_number,
          resource_id: page_id
        }
      ) do
    attached_objectives =
      case activity_revision.objectives do
        nil -> []
        list when is_list(list) -> list
        map when is_map(map) -> Map.get(map, part_id, [])
      end

    %{
      "actor" => %{
        "account" => %{
          "homePage" => host_name,
          "name" => user_id
        },
        "objectType" => "Agent"
      },
      "verb" => %{
        "id" => "http://adlnet.gov/expapi/verbs/completed",
        "display" => %{
          "en-US" => "completed"
        }
      },
      "object" => %{
        "id" => "#{host_name}/part_attempt/#{part_attempt_guid}}",
        "definition" => %{
          "name" => %{
            "en-US" => "Part Attempt"
          },
          "type" => "http://adlnet.gov/expapi/activities/question"
        },
        "objectType" => "Activity"
      },
      "result" => %{
        "score" => %{
          "scaled" =>
            if out_of == 0.0 do
              0.0
            else
              score / out_of
            end,
          "raw" => score,
          "min" => 0,
          "max" => out_of
        },
        "response" => response,
        "completion" => true,
        "success" => true,
        "extensions" => %{
          "http://oli.cmu.edu/extensions/feedback" => feedback
        }
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/hints_requested" => hints,
          "http://oli.cmu.edu/extensions/part_attempt_number" => part_attempt_number,
          "http://oli.cmu.edu/extensions/activity_attempt_number" =>
            activity_attempt.attempt_number,
          "http://oli.cmu.edu/extensions/page_attempt_number" => page_attempt_number,
          "http://oli.cmu.edu/extensions/part_attempt_guid" => part_attempt_guid,
          "http://oli.cmu.edu/extensions/activity_attempt_guid" => activity_attempt.attempt_guid,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => page_attempt_guid,
          "http://oli.cmu.edu/extensions/section_id" => section_id,
          "http://oli.cmu.edu/extensions/project_id" => project_id,
          "http://oli.cmu.edu/extensions/publication_id" => publication_id,
          "http://oli.cmu.edu/extensions/page_id" => page_id,
          "http://oli.cmu.edu/extensions/activity_id" => activity_revision.resource_id,
          "http://oli.cmu.edu/extensions/activity_revision_id" => activity_revision.id,
          "http://oli.cmu.edu/extensions/part_id" => part_id,
          "http://oli.cmu.edu/extensions/attached_objectives" => attached_objectives,
          "http://oli.cmu.edu/extensions/session_id" => session_id
        }
      },
      "timestamp" => timestamp
    }
  end
end
