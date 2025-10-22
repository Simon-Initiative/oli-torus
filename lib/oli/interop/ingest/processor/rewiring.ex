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
  def rewire_bank_selections(content, tag_map) do
    {mapped, _} =
      PageContent.map_reduce(content, {:ok, []}, fn e, {status, invalid_refs}, _tr_context ->
        case e do
          %{"type" => "selection", "logic" => logic} = ref ->
            case logic do
              %{
                "conditions" => %{
                  "children" => [
                    %{"fact" => "tags", "value" => originals, "operator" => operator}
                  ]
                }
              } ->
                Enum.reduce(originals, {[], {:ok, []}}, fn o, {ids, {status, invalid_ids}} ->
                  case retrieve(tag_map, o) do
                    nil ->
                      {ids, {:error, [o | invalid_ids]}}

                    retrieved ->
                      {[retrieved | ids], {status, invalid_ids}}
                  end
                end)
                |> case do
                  {ids, {:ok, _}} ->
                    children = [%{"fact" => "tags", "value" => ids, "operator" => operator}]
                    conditions = Map.put(logic["conditions"], "children", children)
                    logic = Map.put(logic, "conditions", conditions)

                    {Map.put(ref, "logic", logic), {status, invalid_refs}}

                  {_, {:error, invalid_ids}} ->
                    {ref, {status, invalid_ids ++ invalid_refs}}
                end

              %{"conditions" => %{"fact" => "tags", "value" => originals, "operator" => operator}} ->
                Enum.reduce(originals, {[], {:ok, []}}, fn o, {ids, {status, invalid_ids}} ->
                  case retrieve(tag_map, o) do
                    nil ->
                      {ids, {:error, [o | invalid_ids]}}

                    retrieved ->
                      {[retrieved | ids], {status, invalid_ids}}
                  end
                end)
                |> case do
                  {ids, {:ok, _}} ->
                    updated = %{"fact" => "tags", "value" => ids, "operator" => operator}
                    logic = Map.put(logic, "conditions", updated)

                    {Map.put(ref, "logic", logic), {status, invalid_refs}}

                  {_, {:error, invalid_ids}} ->
                    {ref, {status, invalid_ids ++ invalid_refs}}
                end

              _ ->
                {ref, {status, invalid_refs}}
            end

          other ->
            {other, {status, invalid_refs}}
        end
      end)

    mapped
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
