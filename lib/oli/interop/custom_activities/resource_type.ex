defmodule Oli.Interop.CustomActivities.ResourceType do

  import XmlBuilder

  def setup(
        %{
          id: id,
          name: name
        }
      ) do
    element(
      :resource_type,
      %{
        id: id,
        name: name
      }
    )
  end
end
