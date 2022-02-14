defmodule Oli.Interop.CustomActivities.Metadata do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{User, Authorizations, Section, Registration, Activity, WebContent}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :metadata,
      %{
        status: "during"
      },
      [
        User.setup(
          %{
            context: context
          }
        ),
        Authorizations.setup(
          %{
            context: context
          }
        ),
        Section.setup(
          %{
            context: context
          }
        ),
        Registration.setup(
          %{
            context: context
          }
        ),
        Activity.setup(
          %{
            context: context
          }
        ),
        WebContent.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
