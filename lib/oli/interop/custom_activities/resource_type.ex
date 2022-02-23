defmodule Oli.Interop.CustomActivities.ResourceType do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :resource_type,
      %{
        id: context.activity_attempt.revision.activity_type.slug,
        name: context.activity_attempt.revision.activity_type.title
      }
    )
  end
end
