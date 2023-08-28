defmodule Oli.Analytics.Summary.EvaluatedAttempt do

  def new(%{
    actor: %{
      user_id: user_id
    },
    object: %{
      part_attempt_guid: part_attempt_guid,
      response: response,
    },
    result: %{
      score: score,
      out_of: out_of,
      feedback: feedback,
      timestamp: timestamp
    },
    context: %{
      host_name: host_name,
      section_id: section_id,
      project_id: project_id,
      publication_id: publication_id,
      page_id: page_id,
      activity_id: activity_id,
      activity_revision_id: activity_revision_id,
      part_id: part_id,
      user_id: user_id
    }
  }) do
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
          "scaled" => if out_of == 0.0 do 0.0 else score / out_of end,
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
          "http://oli.cmu.edu/extensions/section_id" => section_id,
          "http://oli.cmu.edu/extensions/project_id" => project_id,
          "http://oli.cmu.edu/extensions/publication_id" => publication_id,
          "http://oli.cmu.edu/extensions/page_id" => page_id,
          "http://oli.cmu.edu/extensions/activity_id" => activity_id,
          "http://oli.cmu.edu/extensions/activity_revision_id" => activity_revision_id,
          "http://oli.cmu.edu/extensions/part_id" => part_id
        }
      },
      "timestamp" => timestamp
    }
  end

end
