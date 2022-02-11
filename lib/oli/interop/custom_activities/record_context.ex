defmodule Oli.Interop.CustomActivities.RecordContext do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :record_context,
      %{
        activity_guid: context.activity_attempt.attempt_guid,
        attempt: context.activity_attempt.attempt_number,
        user_guid: context.user.id
      }
    )
  end
end
