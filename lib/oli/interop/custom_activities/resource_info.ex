defmodule Oli.Interop.CustomActivities.ResourceInfo do

  alias Oli.Interop.CustomActivities.{File, ResourceFiles}
  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :resource_info,
      %{
        guid: context.activity_attempt.resource_id,
        id: context.activity_attempt.resource_id,
        title: context.activity_attempt.revision.title,
        type: context.activity_attempt.revision.activity_type.slug
      },
      [
        File.setup(
          %{
            context: context
          }
        ),
        ResourceFiles.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
