defmodule Oli.Rendering.Content.ActivityBankSelectionCriteria do
  @moduledoc false

  alias Oli.Activities
  alias Oli.Activities.Realizer.Logic.{Clause, Expression}
  alias Oli.Activities.Realizer.Selection
  alias Oli.Publishing.DeliveryResolver

  def rows(selection, section_slug) when is_binary(section_slug) do
    activity_type_titles_by_id =
      Activities.list_activity_registrations()
      |> Map.new(fn activity_type -> {activity_type.id, activity_type.title} end)

    parsed_selection = parse_selection(selection)
    criteria_resource_titles_by_id = criteria_resource_titles(section_slug, parsed_selection)

    rows(parsed_selection, activity_type_titles_by_id, criteria_resource_titles_by_id)
  end

  def resource_titles(section_slug, selection_data) when is_binary(section_slug) do
    resource_ids =
      selection_data
      |> Enum.flat_map(fn {_selection, parsed_selection} ->
        criteria_resource_ids(parsed_selection)
      end)
      |> Enum.uniq()

    if resource_ids == [] do
      %{}
    else
      section_slug
      |> DeliveryResolver.from_resource_id(resource_ids)
      |> Enum.reject(&is_nil/1)
      |> Map.new(fn revision -> {revision.resource_id, revision.title} end)
    end
  end

  def rows(
        %Selection{logic: %{conditions: nil}},
        _activity_type_titles_by_id,
        _criteria_resource_titles_by_id
      ),
      do: []

  def rows(
        %Selection{logic: %{conditions: conditions}},
        activity_type_titles_by_id,
        criteria_resource_titles_by_id
      ) do
    conditions
    |> collect_criteria(activity_type_titles_by_id, criteria_resource_titles_by_id)
    |> Enum.reduce([], fn {label, values}, groups ->
      merge_criteria_group(groups, label, values)
    end)
  end

  def rows(_selection, _activity_type_titles_by_id, _criteria_resource_titles_by_id), do: []

  defp parse_selection(%Selection{} = selection), do: selection

  defp parse_selection(selection) do
    case Selection.parse(selection) do
      {:ok, parsed_selection} -> parsed_selection
      _ -> nil
    end
  end

  defp collect_criteria(%Clause{children: children}, activity_type_titles_by_id, titles_by_id),
    do: Enum.flat_map(children, &collect_criteria(&1, activity_type_titles_by_id, titles_by_id))

  defp collect_criteria(
         %Expression{fact: :tags, operator: operator, value: values},
         _activity_type_titles_by_id,
         titles_by_id
       )
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Tags",
       labels_for_resource_ids(values, titles_by_id)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :objectives, operator: operator, value: values},
         _activity_type_titles_by_id,
         titles_by_id
       )
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Learning Objectives",
       labels_for_resource_ids(values, titles_by_id)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :type, operator: operator, value: values},
         activity_type_titles_by_id,
         _titles_by_id
       )
       when is_list(values) do
    [
      {"#{criteria_exclusion_prefix(operator)}Activity Types",
       labels_for_activity_type_ids(values, activity_type_titles_by_id)}
    ]
  end

  defp collect_criteria(%Expression{} = expression, _activity_type_titles_by_id, _titles_by_id) do
    [
      {"#{criteria_exclusion_prefix(expression.operator)}Other",
       [criterion_value(expression.value)]}
    ]
  end

  defp collect_criteria(_condition, _activity_type_titles_by_id, _titles_by_id), do: []

  defp criteria_resource_titles(_section_slug, nil), do: %{}

  defp criteria_resource_titles(section_slug, parsed_selection) do
    resource_titles(section_slug, [{nil, parsed_selection}])
  end

  defp criteria_resource_ids(%Selection{logic: %{conditions: conditions}}),
    do: collect_criteria_resource_ids(conditions)

  defp criteria_resource_ids(_selection), do: []

  defp collect_criteria_resource_ids(%Clause{children: children}),
    do: Enum.flat_map(children, &collect_criteria_resource_ids/1)

  defp collect_criteria_resource_ids(%Expression{fact: fact, value: values})
       when fact in [:tags, :objectives] and is_list(values),
       do: values

  defp collect_criteria_resource_ids(_condition), do: []

  defp merge_criteria_group(groups, label, values) do
    case Enum.find_index(groups, &(&1.label == label)) do
      nil ->
        groups ++ [%{label: label, values: Enum.uniq(values)}]

      index ->
        List.update_at(groups, index, fn group ->
          %{group | values: Enum.uniq(group.values ++ values)}
        end)
    end
  end

  defp criteria_exclusion_prefix(operator)
       when operator in [:does_not_contain, :does_not_equal, "does_not_contain", "does_not_equal"],
       do: "Excluded "

  defp criteria_exclusion_prefix(_operator), do: ""

  defp labels_for_resource_ids(resource_ids, titles_by_id) do
    Enum.map(resource_ids, fn resource_id ->
      Map.get(titles_by_id, resource_id, to_string(resource_id))
    end)
  end

  defp labels_for_activity_type_ids(activity_type_ids, activity_type_titles_by_id) do
    Enum.map(activity_type_ids, fn activity_type_id ->
      Map.get(activity_type_titles_by_id, activity_type_id, to_string(activity_type_id))
    end)
  end

  defp criterion_value(value) when is_list(value), do: Enum.map_join(value, ", ", &to_string/1)
  defp criterion_value(value), do: to_string(value)
end
