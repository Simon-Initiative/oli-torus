defmodule Oli.Interop.CustomActivities.ItemInfo do

  alias Oli.Interop.CustomActivities.{ResourceInfo}
  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :item_info,
      %{
        guid: context.resource_access.id,
        id: context.resource_access.id,
        organization_guid: "multiple",
        purpose: "none",
        scoring_mode: context.activity_attempt.revision.scoring_strategy.type
      },
      [
        ResourceInfo.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
