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

  defp apply(_, {:append, to_append}, _, target, _), do: {:ok, append_to(target, to_append)}
  defp apply(_, {:insert, to_insert}, _, target, _), do: {:ok, insert_in(target, to_insert)}
  defp apply(_, {:remove, to_remove}, _, target, _), do: {:ok, remove_from(target, to_remove)}

  defp apply({:append, to_append}, _, _, _, target), do: {:ok, append_to(target, to_append)}
  defp apply({:insert, to_insert}, _, _, _, target), do: {:ok, insert_in(target, to_insert)}
  defp apply({:remove, to_remove}, _, _, _, target), do: {:ok, remove_from(target, to_remove)}

  defp apply(_, {:other}, src_o, src_c, dest),
    do: {:ok, append_remove(src_o, src_c, dest)}

  defp apply(_, _, _, _, _),
    do: {:no_change}

  # append the items in to_append to list, but ensuring that we do not
  # allow any duplicate elements to be added
  defp append_to(list, to_append) do
    set = MapSet.new(list)
    list ++ Enum.filter(to_append, fn id -> !MapSet.member?(set, id) end)
  end

  # insert the items in to_insert to list, but ensuring that we do not
  # allow any duplicate elements to be added
  defp insert_in(list, to_insert) do
    set = MapSet.new(list)

    Enum.reduce(to_insert, list, fn {id, index}, all ->
      if MapSet.member?(set, id) do
        all
      else
        List.insert_at(all, index, id)
      end
    end)
  end

  defp remove_from(list, to_remove) do
    set = MapSet.new(to_remove)
    Enum.filter(list, fn id -> !MapSet.member?(set, id) end)
  end

  defp append_remove(src_o, src_c, dest) do
    set_o = MapSet.new(src_o)
    set_c = MapSet.new(src_c)
    new_items = MapSet.difference(set_c, set_o) |> MapSet.to_list()
    removed_items = MapSet.difference(set_o, set_c)

    Enum.filter(dest, fn id -> !MapSet.member?(removed_items, id) end) ++ new_items
  end
end
