defmodule Oli.Interop.CustomActivities.LaunchAttributes do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{Attribute}
  def setup(
        %{
          context: _context
        }
      ) do
    element(
      :launch_attributes,
      [
        Attribute.setup(
          %{
            attribute_id: "height",
            value: "300"
          }
        ),
        Attribute.setup(
          %{
            attribute_id: "width",
            value: "670"
          }
        )
      ]
    )
  end
end
