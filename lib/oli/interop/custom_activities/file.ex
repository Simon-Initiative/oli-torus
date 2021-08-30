defmodule Oli.Interop.CustomActivities.File do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :file,
      %{
        guid: "guid",
        href: "file",
        mime_type: "text/xml"
      }
    )
  end
end
