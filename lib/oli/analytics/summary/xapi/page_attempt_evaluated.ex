defmodule Oli.Analytics.Summary.XAPI.PageAttemptEvaluated do
  alias Oli.Analytics.Summary.Context

  def new(
        %Context{
          user_id: user_id,
          host_name: host_name,
          section_id: section_id,
          project_id: project_id,
          publication_id: publication_id
        },
        %{
          attempt_guid: attempt_guid,
          attempt_number: attempt_number,
          resource_id: page_id,
          score: score,
          out_of: out_of,
          date_evaluated: timestamp
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
        "id" => "http://adlnet.gov/expapi/verbs/completed",
        "display" => %{
          "en-US" => "completed"
        }
      },
      "object" => %{
        "id" => "#{host_name}/page_attempt/#{attempt_guid}}",
        "definition" => %{
          "name" => %{
            "en-US" => "Page Attempt"
          },
          "type" => "http://oli.cmu.edu/extensions/page_attempt"
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
        "completion" => true,
        "success" => true
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/page_attempt_number" => attempt_number,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => attempt_guid,
          "http://oli.cmu.edu/extensions/section_id" => section_id,
          "http://oli.cmu.edu/extensions/project_id" => project_id,
          "http://oli.cmu.edu/extensions/publication_id" => publication_id,
          "http://oli.cmu.edu/extensions/page_id" => page_id
        }
      },
      "timestamp" => timestamp
    }
  end
end
