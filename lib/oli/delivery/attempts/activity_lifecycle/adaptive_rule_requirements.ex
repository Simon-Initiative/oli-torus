defmodule Oli.Delivery.Attempts.ActivityLifecycle.AdaptiveRuleRequirements do
  @moduledoc """
  Infers adaptive screen dependencies needed to evaluate rule facts.

  Migrated adaptive content can contain stale resource ids in
  `activitiesRequiredForEvaluation`, while its rules still reference prior screens by
  stable deck sequence ids. This module combines both sources so delivery can load
  the prior activity attempts needed by the rules engine.
  """

  @doc """
  Returns the activity resource ids required to evaluate the given adaptive rules.
  """
  @spec infer(map(), list() | nil, list() | nil) :: [integer()]
  def infer(resource_attempt, activities_required_for_evaluation, rules) do
    sequence_activity_map =
      resource_attempt
      |> page_content()
      |> activity_sequence_map()

    inferred_activity_ids =
      rules
      |> referenced_sequence_ids()
      |> Enum.reduce([], fn sequence_id, activity_ids ->
        case Map.get(sequence_activity_map, sequence_id) do
          nil -> activity_ids
          activity_id -> [activity_id | activity_ids]
        end
      end)

    (normalize_required_activity_ids(activities_required_for_evaluation) ++ inferred_activity_ids)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp normalize_required_activity_ids(ids) when is_list(ids) do
    Enum.map(ids, fn
      id when is_integer(id) ->
        id

      id when is_binary(id) ->
        case Integer.parse(id) do
          {integer, ""} -> integer
          _ -> nil
        end

      _ ->
        nil
    end)
  end

  defp normalize_required_activity_ids(_), do: []

  defp page_content(%{content: content}) when is_map(content) and content != %{}, do: content
  defp page_content(%{revision: %{content: content}}) when is_map(content), do: content
  defp page_content(_), do: %{}

  defp activity_sequence_map(content) do
    content
    |> collect_activity_sequence_refs([])
    |> Map.new()
  end

  defp collect_activity_sequence_refs(%{} = map, refs) do
    refs =
      case map do
        %{
          "type" => "activity-reference",
          "activity_id" => activity_id,
          "custom" => %{"sequenceId" => sequence_id}
        }
        when is_binary(sequence_id) ->
          [{sequence_id, activity_id} | refs]

        _ ->
          refs
      end

    map
    |> Map.values()
    |> Enum.reduce(refs, &collect_activity_sequence_refs/2)
  end

  defp collect_activity_sequence_refs(values, refs) when is_list(values) do
    Enum.reduce(values, refs, &collect_activity_sequence_refs/2)
  end

  defp collect_activity_sequence_refs(_value, refs), do: refs

  defp referenced_sequence_ids(rules) do
    rules
    |> collect_rule_facts([])
    |> Enum.flat_map(fn fact ->
      case String.split(fact, "|", parts: 2) do
        [sequence_id, _local_fact] -> [sequence_id]
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp collect_rule_facts(%{"fact" => fact} = map, facts) when is_binary(fact) do
    map
    |> Map.delete("fact")
    |> collect_rule_facts([fact | facts])
  end

  defp collect_rule_facts(%{} = map, facts) do
    map
    |> Map.values()
    |> Enum.reduce(facts, &collect_rule_facts/2)
  end

  defp collect_rule_facts(values, facts) when is_list(values) do
    Enum.reduce(values, facts, &collect_rule_facts/2)
  end

  defp collect_rule_facts(_value, facts), do: facts
end
