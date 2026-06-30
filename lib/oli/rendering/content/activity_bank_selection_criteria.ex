defmodule Oli.Rendering.Content.ActivityBankSelectionCriteria do
  @moduledoc """
  Builds the instructor-facing presentation for Activity Bank selection criteria.

  This module translates authored selection logic into instructor-facing labels for preview
  surfaces.

  Current UX rules:

  - show top-level clause context as "Activities must match all of the following." /
    "Activities may match any of the following."
  - for tags and learning objectives:
    - `contains` -> "... contain"
    - `equals` -> "... equal"
    - `does_not_contain` -> "... do not contain"
    - `does_not_equal` -> "... do not equal"
  - for activity types:
    - `contains` -> "Activity Types contain"
    - `does_not_contain` -> "Activity Types do not contain"

  Both the React-based preview card and the LiveView manager use this module so those surfaces
  stay aligned as criteria presentation evolves.
  """

  alias Oli.Activities
  alias Oli.Activities.Realizer.Logic.{Clause, Expression}
  alias Oli.Activities.Realizer.Selection
  alias Oli.Publishing.DeliveryResolver

  @doc """
  Returns the full criteria presentation for a single selection.

  The result contains:

  - `:helper_text` for the top-level all/any clause, when present
  - `:rows` for the rendered criteria groups and values
  """
  def presentation(selection, section_slug) when is_binary(section_slug) do
    activity_type_titles_by_id =
      Activities.list_activity_registrations()
      |> Map.new(fn activity_type -> {activity_type.id, activity_type.title} end)

    parsed_selection = parse_selection(selection)
    criteria_resource_titles_by_id = criteria_resource_titles(section_slug, parsed_selection)

    presentation(parsed_selection, activity_type_titles_by_id, criteria_resource_titles_by_id)
  end

  @doc """
  Returns only the criteria rows for a selection.

  This is a convenience wrapper when the caller does not need the clause helper text.
  """
  def rows(selection, section_slug) when is_binary(section_slug) do
    selection
    |> presentation(section_slug)
    |> Map.get(:rows, [])
  end

  @doc """
  Resolves titles for tag/objective resource ids used by one or more selections.

  Callers that already have multiple parsed selections can use this to avoid resolving labels
  one resource at a time.
  """
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

  def presentation(
        %Selection{logic: %{conditions: nil}},
        _activity_type_titles_by_id,
        _criteria_resource_titles_by_id
      ),
      do: %{helper_text: nil, rows: []}

  def presentation(
        %Selection{logic: %{conditions: conditions}},
        activity_type_titles_by_id,
        criteria_resource_titles_by_id
      ) do
    %{
      helper_text: helper_text(conditions),
      rows: build_rows(conditions, activity_type_titles_by_id, criteria_resource_titles_by_id)
    }
  end

  def presentation(_selection, _activity_type_titles_by_id, _criteria_resource_titles_by_id),
    do: %{helper_text: nil, rows: []}

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
      ),
      do: build_rows(conditions, activity_type_titles_by_id, criteria_resource_titles_by_id)

  def rows(_selection, _activity_type_titles_by_id, _criteria_resource_titles_by_id), do: []

  defp parse_selection(%Selection{} = selection), do: selection

  defp parse_selection(selection) do
    case Selection.parse(selection) do
      {:ok, parsed_selection} -> parsed_selection
      _ -> nil
    end
  end

  defp build_rows(conditions, activity_type_titles_by_id, criteria_resource_titles_by_id) do
    conditions
    |> collect_criteria(activity_type_titles_by_id, criteria_resource_titles_by_id)
    |> Enum.reduce([], fn {label, values}, groups ->
      merge_criteria_group(groups, label, values)
    end)
  end

  defp collect_criteria(%Clause{children: children}, activity_type_titles_by_id, titles_by_id),
    do: Enum.flat_map(children, &collect_criteria(&1, activity_type_titles_by_id, titles_by_id))

  # Labels intentionally use the authored operator words (equal / contain / do not equal /
  # do not contain) so the preview remains transparent about the real selection semantics.
  defp collect_criteria(
         %Expression{fact: :tags, operator: operator, value: values},
         _activity_type_titles_by_id,
         titles_by_id
       )
       when is_list(values) do
    [
      {criteria_label(:tags, operator), labels_for_resource_ids(values, titles_by_id)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :objectives, operator: operator, value: values},
         _activity_type_titles_by_id,
         titles_by_id
       )
       when is_list(values) do
    [
      {criteria_label(:objectives, operator), labels_for_resource_ids(values, titles_by_id)}
    ]
  end

  defp collect_criteria(
         %Expression{fact: :type, operator: operator, value: values},
         activity_type_titles_by_id,
         _titles_by_id
       )
       when is_list(values) do
    [
      {criteria_label(:type, operator),
       labels_for_activity_type_ids(values, activity_type_titles_by_id)}
    ]
  end

  # Unknown facts still surface as criteria so authored rules are not silently hidden from
  # instructors, but they fall back to a generic label.
  defp collect_criteria(%Expression{} = expression, _activity_type_titles_by_id, _titles_by_id) do
    [
      {criteria_label(:other, expression.operator), [criterion_value(expression.value)]}
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

  # The top-level clause is shown as supporting context instead of repeating all/any in each row.
  defp helper_text(%Clause{operator: :all}), do: "Activities must match all of the following."
  defp helper_text(%Clause{operator: :any}), do: "Activities may match any of the following."
  defp helper_text(%Clause{operator: "all"}), do: "Activities must match all of the following."
  defp helper_text(%Clause{operator: "any"}), do: "Activities may match any of the following."
  defp helper_text(_conditions), do: nil

  defp criteria_label(:tags, operator) when operator in [:contains, "contains"],
    do: "Tags contain"

  defp criteria_label(:tags, operator) when operator in [:equals, "equals"],
    do: "Tags equal"

  defp criteria_label(:tags, operator) when operator in [:does_not_contain, "does_not_contain"],
    do: "Tags do not contain"

  defp criteria_label(:tags, operator) when operator in [:does_not_equal, "does_not_equal"],
    do: "Tags do not equal"

  defp criteria_label(:objectives, operator) when operator in [:contains, "contains"],
    do: "Learning Objectives contain"

  defp criteria_label(:objectives, operator) when operator in [:equals, "equals"],
    do: "Learning Objectives equal"

  defp criteria_label(:objectives, operator)
       when operator in [:does_not_contain, "does_not_contain"],
       do: "Learning Objectives do not contain"

  defp criteria_label(:objectives, operator)
       when operator in [:does_not_equal, "does_not_equal"],
       do: "Learning Objectives do not equal"

  defp criteria_label(:type, operator)
       when operator in [:does_not_contain, :does_not_equal, "does_not_contain", "does_not_equal"],
       do: "Activity Types do not contain"

  defp criteria_label(:type, _operator), do: "Activity Types contain"

  defp criteria_label(:other, operator)
       when operator in [:does_not_contain, :does_not_equal, "does_not_contain", "does_not_equal"],
       do: "Excluded Other"

  defp criteria_label(:other, _operator), do: "Other"

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
