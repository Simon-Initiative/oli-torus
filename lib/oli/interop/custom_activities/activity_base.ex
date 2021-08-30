defmodule Oli.Interop.CustomActivities.ActivityBase do

  import XmlBuilder

  def setup(
        %{
          href: href
        }
      ) do
    element(
      :base,
      %{
        href: href
      }
    )
  end
end
