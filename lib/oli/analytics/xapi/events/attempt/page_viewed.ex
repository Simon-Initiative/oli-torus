defmodule Oli.Analytics.XAPI.Events.Attempt.PageViewed do
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
          page_sub_type: page_sub_type
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
        "id" => "http://id.tincanapi.com/verb/viewed",
        "display" => %{
          "en-US" => "viewed"
        }
      },
      "object" => %{
        "id" => "#{host_name}/page/#{page_id}}",
        "definition" => %{
          "name" => %{
            "en-US" => "Page"
          },
          "type" => "http://oli.cmu.edu/extensions/types/page",
          "subType" => page_sub_type
        },
        "objectType" => "Page"
      },
      "result" => %{
        "completion" => true,
        "success" => true
      },
      "context" => %{
        "extensions" => %{
          "http://oli.cmu.edu/extensions/page_attempt_number" => page_attempt_number,
          "http://oli.cmu.edu/extensions/page_attempt_guid" => page_attempt_guid,
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
