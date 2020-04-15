defmodule Oli.Activities.ModeSpecification do

  defstruct [:element, :entry]

  def parse(%{"element" => element, "entry" => entry }) do
    %Oli.Activities.ModeSpecification{element: element, entry: entry}
  end

end
