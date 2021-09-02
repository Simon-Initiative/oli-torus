defmodule Oli.Interop.CustomActivities.SuperActivitySession do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{Metadata, Storage, Grading}

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :super_activity_session,
      [
        Metadata.setup(
          %{
            context: context
          }
        ),
        Storage.setup(
          %{
            context: context
          }
        ),
        Grading.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
