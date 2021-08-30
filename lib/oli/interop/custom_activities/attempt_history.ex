defmodule Oli.Interop.CustomActivities.AttemptHistory do

  alias Lti_1p3.Tool.ContextRoles

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :attempt_history,
      %{
        activity_guid: context.resource_access.id,
        current_attempt: context.activity_attempt.attempt_number,
        date_started: "true",
        date_completed: "true",
        first_accessed: "",
        last_accessed: "",
        last_modified: "",
        max_attempts: "",
        overall_attempt: "",
        user_guid: context.user.email
      }
    )
  end
end
