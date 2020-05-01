defmodule Oli.Delivery.Page.ModelPruner do

  @moduledoc """
  Implements adjustments to activity models so that they can
  be safely delivered to a browser in delivery model.
  """

  @doc """
  Prunes an activity model to remove authoring specific components
  of the model.
  """
  @spec prune(%{}) :: %{}
  def prune(model) do
    Map.delete(model, "authoring")
  end

end
