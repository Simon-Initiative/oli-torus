defmodule Oli.Interop.CustomActivities.Problem do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{GradingAttributes, LaunchAttributes}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :problem,
      %{
        date_created: DateTime.to_unix(context.activity_attempt.revision.inserted_at),
        max_attempts: context.activity_attempt.revision.max_attempts,
        resource_guid: context.activity_attempt.resource_id,
        resource_type_id: context.activity_attempt.revision.activity_type.slug
      },
      [
        GradingAttributes.setup(
          %{
            context: context
          }
        ),
        LaunchAttributes.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
