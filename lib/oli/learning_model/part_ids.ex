defmodule Oli.LearningModel.PartIds do
  @moduledoc """
  Resolves activity part IDs that may receive learning-model parameters.

  Standard activities use their authored parts. Adaptive activities reuse the
  canonical persisted-part semantics from `Oli.Activities.AdaptiveParts`.
  """

  alias Oli.Activities.AdaptiveParts

  @spec for_content(term()) :: MapSet.t(String.t())
  def for_content(content) when is_map(content) do
    if adaptive_content?(content) do
      adaptive_part_ids(content)
    else
      authored_part_ids(content)
    end
  end

  def for_content(_content), do: MapSet.new()

  defp adaptive_content?(content) do
    Map.get(content, "advancedDelivery") == true or
      Map.get(content, "advancedAuthoring") == true or
      Map.has_key?(content, "partsLayout")
  end

  defp adaptive_part_ids(content) do
    if valid_adaptive_shape?(content) do
      AdaptiveParts.persisted_part_ids(content)
    else
      MapSet.new()
    end
  end

  defp valid_adaptive_shape?(content) do
    parts_layout = Map.get(content, "partsLayout", [])
    authoring = Map.get(content, "authoring", %{})

    is_list(parts_layout) and Enum.all?(parts_layout, &is_map/1) and is_map(authoring) and
      valid_map_list?(Map.get(authoring, "parts", [])) and
      valid_map_list?(Map.get(authoring, "rules", []))
  end

  defp valid_map_list?(items), do: is_list(items) and Enum.all?(items, &is_map/1)

  defp authored_part_ids(content) do
    content
    |> get_in(["authoring", "parts"])
    |> case do
      parts when is_list(parts) -> parts
      _ -> []
    end
    |> Enum.reduce(MapSet.new(), fn
      %{"id" => part_id}, acc when is_binary(part_id) and part_id != "" ->
        MapSet.put(acc, part_id)

      part_id, acc when is_binary(part_id) and part_id != "" ->
        MapSet.put(acc, part_id)

      _part, acc ->
        acc
    end)
  end
end
