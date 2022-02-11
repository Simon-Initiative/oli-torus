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
        href: context.web_content_url
      }
    )
  end
end
