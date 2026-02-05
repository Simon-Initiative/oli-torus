defmodule Oli.Activities.Model do
  @moduledoc """
  Struct representation of an activity model.  This representation differs
  slightly from the true client side representation - here we elevate the
  two components that can exist in the authoring section to the top-level
  level. This allows then both `delivery` and `authoring` to be black
  boxes.  It is also easier to represent as a struct in this manner.
  """

  defstruct [:parts, :transformations, :delivery, :authoring, :rules]

  def parse(%{"authoring" => authoring} = model) when is_map(authoring) do
    targeted_response_ids =
      Map.get(authoring, "targeted", [])
      |> Enum.map(fn
        [_, response_id] -> response_id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    parts_with_targeted =
      Map.get(authoring, "parts", [])
      |> Enum.map(fn part ->
        response_ids =
          Map.get(part, "responses", [])
          |> Enum.map(fn r -> Map.get(r, "id") end)
          |> Enum.reject(&is_nil/1)
          |> MapSet.new()

        targeted_for_part =
          MapSet.intersection(targeted_response_ids, response_ids)
          |> MapSet.to_list()

        Map.put(part, "targetedResponseIds", targeted_for_part)
      end)

    with {:ok, parts} <- Oli.Activities.Model.Part.parse(parts_with_targeted),
         {:ok, rules} <-
           Oli.Activities.Model.ConditionalOutcome.parse(Map.get(authoring, "rules", [])),
         {:ok, transformations} <-
           Oli.Activities.Model.Transformation.parse(Map.get(authoring, "transformations", [])) do
      {:ok,
       %Oli.Activities.Model{
         parts: parts,
         rules: rules,
         transformations: transformations,
         authoring: Map.drop(authoring, ["parts", "transformations", "rules"]),
         delivery: Map.drop(model, ["authoring"])
       }}
    else
      error -> error
    end
  end

  def parse(%{"authoring" => authoring} = model) do
    {:ok,
     %Oli.Activities.Model{
       parts: [],
       rules: [],
       transformations: [],
       authoring: authoring,
       delivery: Map.drop(model, ["authoring"])
     }}
  end

  def parse(model) do
    {:ok,
     %Oli.Activities.Model{
       parts: [],
       rules: [],
       transformations: [],
       authoring: %{},
       delivery: model
     }}
  end
end
