defmodule Oli.Interop.CustomActivities.ActivityBase do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :base,
      %{
        href: "#{context.host_url}/superactivity/#{context.base}"
      }
    )
  end
end
