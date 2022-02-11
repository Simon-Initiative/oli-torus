defmodule Oli.Interop.CustomActivities.Url do

  import XmlBuilder

  def setup(
        %{
          url_text: url_text
        }
      ) do
    element(:url, url_text)
  end
end
