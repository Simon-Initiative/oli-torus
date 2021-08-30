defmodule Oli.Interop.CustomActivities.Grading do

  import XmlBuilder

  def setup(
        %{
          context: context
        }
      ) do
    element(
      :grading,[]

    )
  end
end
