defmodule Oli.Interop.Ingest.Processing.Rewiring do
  @moduledoc """
  Rewiring functions for the ingest processor.
  This module is responsible for rewiring (updating or remapping) references inside content data structures during an ingest (import) process.
  When content is imported, IDs for activities, tags, bibliographic references, etc., may change. This module updates those references in the content to point to the new, correct IDs.
  """

  alias Oli.Resources.PageContent

  defp retrieve(map, key) do
    case Map.get(map, key) do
      nil ->
        Map.get(map, Integer.to_string(key, 10))

      m ->
        m
    end
  end

  @spec rewire_activity_references(map() | nil, any) :: map() | nil
  def rewire_activity_references(content, activity_map) do
    {mapped, _} =
      PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
        case e do
          %{"type" => "activity-reference", "activity_id" => original} = ref ->
            case retrieve(activity_map, original) do
              nil ->
                {nil, {:error, [original | invalid_refs]}}

              retrieved ->
                {Map.put(ref, "activity_id", retrieved), {status, invalid_refs}}
            end

          other ->
            {other, {status, invalid_refs}}
        end
      end)

    prune_nil_nodes(mapped)
  end

  @spec rewire_report_activity_references(map(), any) :: map()
  def rewire_report_activity_references(content, activity_map) do
    {mapped, _} =
      PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
        case e do
          %{"type" => "report", "activityId" => original} = ref ->
            case retrieve(activity_map, original) do
              nil ->
                {ref, {:error, [original | invalid_refs]}}

              retrieved ->
                {Map.put(ref, "activityId", retrieved), {status, invalid_refs}}
            end

          other ->
            {other, {status, invalid_refs}}
        end
      end)

    mapped
  end

  @spec rewire_bank_selections(map(), any) :: map()
  def rewire_bank_selections(content, id_map) do
    {mapped, _} =
      PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
        case e do
          %{"type" => "selection", "logic" => logic} = ref ->
            rewired_logic = rewire_bank_selection_logic(logic, id_map)
            {Map.put(ref, "logic", rewired_logic), {status, invalid_refs}}

          other ->
            {other, {status, invalid_refs}}
        end
      end)

    mapped
  end

  # Recursively rewire bank selection logic conditions
  defp rewire_bank_selection_logic(%{"conditions" => nil} = logic, _id_map) do
    logic
  end

  defp rewire_bank_selection_logic(%{"conditions" => conditions} = logic, id_map) do
    rewired_conditions = rewire_logic_conditions(conditions, id_map)
    Map.put(logic, "conditions", rewired_conditions)
  end

  defp rewire_bank_selection_logic(logic, _id_map) when is_map(logic) do
    # Handle case where logic might not have "conditions" key
    logic
  end

  # Handle clause with operator and children
  defp rewire_logic_conditions(
         %{"operator" => _operator, "children" => children} = clause,
         id_map
       ) do
    rewired_children = Enum.map(children, &rewire_logic_conditions(&1, id_map))
    Map.put(clause, "children", rewired_children)
  end

  # Handle expression with fact, operator, and value - rewire IDs for tags and objectives
  defp rewire_logic_conditions(
         %{"fact" => fact, "operator" => _operator, "value" => value} = expression,
         id_map
       )
       when fact in ["objectives", "tags"] do
    # Rewire IDs from legacy IDs to new resource IDs
    rewired_value =
      case value do
        list when is_list(list) ->
          Enum.map(list, fn id ->
            case retrieve(id_map, id) do
              nil -> id
              new_id -> new_id
            end
          end)

        other ->
          other
      end

    Map.put(expression, "value", rewired_value)
  end

  # Handle expression with other facts (text, type) - preserve as is
  defp rewire_logic_conditions(%{"fact" => _fact} = expression, _id_map) do
    expression
  end

  # Fallback for any other structure
  defp rewire_logic_conditions(conditions, _id_map) do
    conditions
  end

  defp rewire_bib_refs(%{"type" => "content", "children" => _children} = content, bib_map) do
    PageContent.bibliography_rewire(content, {:ok, []}, fn i, {status, bibrefs}, _tr_context ->
      case i do
        %{"type" => "cite", "bibref" => bibref} = ref ->
          bib_id = Map.get(bib_map, bibref, %{resource_id: bibref})
          {Map.put(ref, "bibref", bib_id), {status, bibrefs ++ [bib_id]}}

        other ->
          {other, {status, bibrefs}}
      end
    end)
  end

  def rewire_citation_references(content, bib_map) do
    brefs =
      Enum.reduce(Map.get(content, "bibrefs", []), [], fn k, acc ->
        if Map.has_key?(bib_map, k) do
          acc ++ [Map.get(bib_map, k, %{id: k})]
        else
          acc
        end
      end)

    bcontent = Map.put(content, "bibrefs", brefs)

    {mapped, _} =
      PageContent.map_reduce(bcontent, {:ok, []}, fn e, {status, bibrefs}, _tr_context ->
        case e do
          %{"type" => "content"} = ref ->
            rewire_bib_refs(ref, bib_map)

          other ->
            {other, {status, bibrefs}}
        end
      end)

    mapped
  end

  def rewire_alternatives_groups(content, legacy_to_resource_id_map) do
    {mapped, _} =
      PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
        case e do
          %{"type" => "alternatives", "group" => original} = ref ->
            case Map.get(legacy_to_resource_id_map, original) do
              nil ->
                {ref, {:error, [original | invalid_refs]}}

              retrieved ->
                {Map.put(ref, "alternatives_id", retrieved), {status, invalid_refs}}
            end

          other ->
            {other, {status, invalid_refs}}
        end
      end)

    mapped
  end

  defp prune_nil_nodes(nil), do: nil

  defp prune_nil_nodes(%_{} = struct), do: struct

  defp prune_nil_nodes(%{} = map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      cleaned = prune_nil_nodes(value)

      cond do
        is_nil(cleaned) ->
          acc

        true ->
          Map.put(acc, key, cleaned)
      end
    end)
  end

  defp prune_nil_nodes(value) when is_list(value) do
    value
    |> Enum.reduce([], fn item, acc ->
      case prune_nil_nodes(item) do
        nil -> acc
        cleaned -> [cleaned | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp prune_nil_nodes(value), do: value
end
