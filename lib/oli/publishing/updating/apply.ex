defmodule Oli.Publishing.Updating.Children do
  use Oli.Publishing.Updating.Types
  alias Oli.Publishing.Updating.Airro

  def update(src_original, src_current, dest) do
    src_changes = Airro.classify(src_original, src_current)
    dest_changes = Airro.classify(src_original, dest)

    apply(src_changes, dest_changes, src_original, src_current, dest)
  end

  defp apply({:equal}, _, _, _, _), do: {:no_change}
  defp apply(_, {:equal}, _, src_current, _), do: {:ok, src_current}
  defp apply(_, {:other}, src_, src_c, dest), do: {:ok, append_remove(src_, src_c, dest)}

  defp append_to() do
  end

  defp append_remove(src_o, src_c, dest) do
    set_o = MapSet.new(src_o)
    set_c = MapSet.new(src_c)
    new_items = MapSet.difference(set_c, set_o) |> MapSet.to_list()
    removed_items = MapSet.difference(set_o, set_c)

    Enum.filter(dest, fn id -> !MapSet.member?(removed_items, id) end) ++ new_items
  end
end
