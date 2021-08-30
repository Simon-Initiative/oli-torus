defmodule Oli.Interop.CustomActivities.Authentication do

  import XmlBuilder

  def setup(
        %{
          user_guid: user_guid
        }
      ) do
    element(
      :authentication,
      %{
        user_guid: user_guid
      }
    )
  end
end
