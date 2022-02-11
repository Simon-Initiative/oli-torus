defmodule Oli.Interop.CustomActivities.User do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :user,
      %{
        anonymous: context.user.guest,
        country: context.user.locale,
        date_created: DateTime.to_unix(context.user.inserted_at),
        email: context.user.email,
        first_name: context.user.given_name,
        last_name: context.user.family_name,
        guid: context.user.id,
        institution: ""
      }
    )
  end
end
