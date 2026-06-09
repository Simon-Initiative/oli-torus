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

    parts_with_input_types = annotate_input_types(parts_with_targeted, model)

    with {:ok, parts} <- Oli.Activities.Model.Part.parse(parts_with_input_types),
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

  defp annotate_input_types(parts, %{"inputs" => inputs}) when is_list(inputs) do
    input_attrs_by_part_id =
      Enum.reduce(inputs, %{}, fn input, acc ->
        case {Map.get(input, "partId"), Map.get(input, "inputType")} do
          {nil, _} ->
            acc

          {_, input_type} when not is_binary(input_type) ->
            acc

          {part_id, input_type} ->
            attrs =
              %{"inputType" => input_type}
              |> maybe_put_item_config(Map.get(input, "itemConfig"))

            Map.put(acc, to_string(part_id), attrs)
        end
      end)

    Enum.map(parts, fn part ->
      case Map.get(input_attrs_by_part_id, to_string(Map.get(part, "id"))) do
        nil -> part
        attrs -> Map.merge(part, attrs)
      end
    end)
  end

  defp annotate_input_types(parts, %{"inputType" => input_type} = model)
       when is_binary(input_type) do
    item_config = Map.get(model, "itemConfig")

    Enum.map(parts, fn part ->
      part
      |> Map.put("inputType", input_type)
      |> maybe_put_item_config(item_config)
    end)
  end

  defp annotate_input_types(parts, _model), do: parts

  defp maybe_put_item_config(part, item_config) when is_map(item_config) do
    Map.put(part, "itemConfig", item_config)
  end

  defp maybe_put_item_config(part, _), do: part
end
