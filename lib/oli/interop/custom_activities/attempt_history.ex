defmodule Oli.Interop.CustomActivities.AttemptHistory do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{Problem, ActivityAttempt}

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
        date_started: DateTime.to_unix(context.resource_attempt.inserted_at),
        date_completed: "true",
        first_accessed: DateTime.to_unix(context.resource_attempt.inserted_at),
        last_accessed: DateTime.to_unix(context.resource_attempt.updated_at),
        last_modified: DateTime.to_unix(context.resource_attempt.updated_at),
        max_attempts: context.resource_attempt.revision.max_attempts,
        overall_attempt: "",
        user_guid: context.user.id
      },
      [
        Problem.setup(
          %{
            context: context
          }
        ),
        context.resource_attempt.activity_attempts
        |> Enum.map(fn attempt ->
          ActivityAttempt.setup(
            %{
              activity_attempt: attempt
            }
          )
        end)
      ]
    )
  end
end
