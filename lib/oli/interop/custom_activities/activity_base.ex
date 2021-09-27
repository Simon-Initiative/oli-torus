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
        href: "#{context.host_url}/superactivity/#{context.activity_attempt.revision.activity_type.slug}"
      }
    )
  end
end
