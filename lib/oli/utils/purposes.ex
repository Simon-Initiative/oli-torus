defmodule Oli.Utils.Purposes do
  def label_for("none"), do: "None"
  def label_for("checkpoint"), do: "Checkpoint"
  def label_for("didigetthis"), do: "Did I get this?"
  def label_for("learnbydoing"), do: "Learn by doing"
  def label_for("manystudentswonder"), do: "Many students wonder"
  def label_for("example"), do: "Example"
  def label_for("learnmore"), do: "Learn More"

  def label_for(purpose), do: String.capitalize(purpose)
end
