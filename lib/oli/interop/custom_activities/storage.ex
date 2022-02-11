defmodule Oli.Interop.CustomActivities.Storage do

  alias Oli.Interop.CustomActivities.{FileDirectory}
  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :storage,
      [
        FileDirectory.setup(
          %{
            context: context
          }
        )
      ]
    )
  end
end
