defmodule Oli.Activities.Model do
  @moduledoc """
  Struct representation of an activity model.  This representation differs
  slightly from the true client side representation - here we elevate the
  two components that can exist in the authoring section to the top-level
  level. This allows then both `delivery` and `authoring` to be black
  boxes.  It is also easier to represent as a struct in this manner.
  """

  defstruct [:parts, :transformations, :delivery, :authoring]

  def parse(%{ "authoring" => authoring} = model) when is_map(authoring) do


    with {:ok, parts} <- Oli.Activities.Model.Part.parse(Map.get(authoring, "parts", [])),
      {:ok, transformations} <- Oli.Activities.Model.Transformation.parse(Map.get(authoring, "transformations", []))
    do
      {:ok, %Oli.Activities.Model{
        parts: parts,
        transformations: transformations,
        authoring: Map.drop(authoring, ["parts", "transformations"]),
        delivery: Map.drop(model, ["authoring"]),
      }}
    else
      error -> error
    end
  end

  def parse(%{ "authoring" => authoring} = model) do
    {:ok, %Oli.Activities.Model{
      parts: [],
      transformations: [],
      authoring: authoring,
      delivery: Map.drop(model, ["authoring"]),
    }}
  end

  def parse(model) do
    {:ok, %Oli.Activities.Model{
      parts: [],
      transformations: [],
      authoring: %{},
      delivery: model,
    }}
  end

end
