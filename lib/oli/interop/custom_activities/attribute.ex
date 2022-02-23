defmodule Oli.Interop.CustomActivities.Attribute do

  import XmlBuilder

  def setup(
        %{
          attribute_id: attribute_id,
          value: value
        }
      ) do
    element(
      :attribute,
      %{
        attribute_id: attribute_id,
        value: value
      }
    )
  end
end
