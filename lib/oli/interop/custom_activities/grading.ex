defmodule Oli.Interop.CustomActivities.Grading do

  import XmlBuilder
  alias Oli.Interop.CustomActivities.{AttemptHistory}
  def setup(
        %{
          context: context
        }
      ) do
    element(
      :grading,
      [
        AttemptHistory.setup(
          %{
            context: context
          }
        )
      ]

    )
  end
end
