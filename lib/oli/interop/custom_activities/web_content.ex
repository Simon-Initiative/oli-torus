defmodule Oli.Interop.CustomActivities.WebContent do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :web_content,
      %{
        href: "https://localhost/repository/webcontent/879446d40a00005672dbed23ee6ca868/"
      }
    )
  end
end
