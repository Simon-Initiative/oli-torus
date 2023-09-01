defmodule Oli.Analytics.Summary.XAPI.ActivityAttemptEvaluated do

  alias Oli.Analytics.Summary.Context
  alias Oli.Analytics.XAPI.Statement
  alias Oli.Delivery.Attempts.Core.ActivityAttempt

  def new(%Context{
    user_id: user_id,
    host_name: host_name,
    section_id: section_id,
    project_id: project_id,
    publication_id: publication_id
  }, %ActivityAttempt{
    attempt_guid: attempt_guid,
    attempt_number: attempt_number,
    score: score,
    out_of: out_of,
    date_evaluated: timestamp,
    resource_id: activity_id,
    revision_id: activity_revision_id
  }, %{
    attempt_guid: page_attempt_guid,
    attempt_number: page_attempt_number,
    resource_id: page_id
  }) do

    body = %{
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
        "id" => "#{host_name}/activity_attempt/#{attempt_guid}}",
        "definition" => %{
          "name" => %{
            "en-US" => "Activity Attempt"
          },
          "type" => "http://oli.cmu.edu/extensions/activity_attempt"
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
        "completion" => true,
        "success" => true
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

    %Statement{
      category: :section,
      category_id: section_id,
      type: :activity_attempt_evaluated,
      type_id: attempt_guid,
      body: body
    }
  end

end
