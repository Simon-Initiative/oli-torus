defmodule Oli.Interop.CustomActivities.GradingAttributes do

  import XmlBuilder

  def setup(
        %{
          context: _context
        }
      ) do
    element(
      :grading_attributes
    )
  end
end
