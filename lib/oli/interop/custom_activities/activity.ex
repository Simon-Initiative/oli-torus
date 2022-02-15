defmodule Oli.Interop.CustomActivities.Activity do

  alias Oli.Interop.CustomActivities.{ItemInfo}

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :activity,
      %{
        guid: context.resource_access.id,
        high_stakes: context.activity_attempt.revision.graded,
        just_in_time: "true",
        section_guid: context.section.id
      },
      [
        ItemInfo.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
