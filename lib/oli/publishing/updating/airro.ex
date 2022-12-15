defmodule Oli.Publishing.Updating.Airro do
  use Oli.Publishing.Updating.Types

  @spec classify(list(id()), list(id())) :: change()
  def classify(a, b) do
    if a == b do
      {:equal}
    else
      set_a = MapSet.new(a)
      set_b = MapSet.new(b)
      len_a = MapSet.size(set_a)
      len_b = MapSet.size(set_b)

      cond do
        len_a == len_b ->
          # can only be one of three cases: equal, reorder or other
          cond do
            a == b -> {:equal}
            MapSet.equal?(set_a, set_b) -> {:reorder}
            true -> {:other}
          end

        len_a < len_b ->
          # can only be insert, append or other
          if MapSet.subset?(set_a, set_b) do
            # if we remove the new ones from b and that does not equal a
            # we know that a reordering also took place, so :other
            without_new = Enum.filter(b, fn e -> MapSet.member?(set_a, e) end)

            if a != without_new do
              {:other}
            else
              map_b =
                Enum.with_index(b)
                |> Enum.reduce(%{}, fn {id, index}, m -> Map.put(m, id, index) end)

              new_items_with_index =
                MapSet.difference(set_b, set_a)
                |> MapSet.to_list()
                |> Enum.map(fn id -> {id, Map.get(map_b, id)} end)

              {_, min} = Enum.min_by(new_items_with_index, fn {_, i} -> i end)

              # if the minimum index of the inserted item is at the end, this is a strict append
              if min >= len_a do
                {:append, Enum.map(new_items_with_index, fn {id, _} -> id end)}
              else
                {:insert, new_items_with_index}
              end
            end
          else
            {:other}
          end

        true ->
          # can only be remove or other
          removed_from_b = MapSet.difference(set_a, set_b)
          a_without_deleted = Enum.filter(a, fn id -> !MapSet.member?(removed_from_b, id) end)

          if a_without_deleted == b do
            {:remove, MapSet.to_list(removed_from_b)}
          else
            {:other}
          end
      end
    end
  end
end
