defmodule Oli.Interop.CustomActivities.Authentication do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :authentication,
      %{
        user_guid: context.user.id
      }
    )
  end
end
