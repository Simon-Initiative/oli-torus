defmodule Oli.Utils.Stagehand.WeightedRandom do
  @doc """
  Randomly selects an item from a list based on its weighted probability.

  ## Examples

      iex> WeightedRandom.choose([{"A", 0.6}, {"B", 0.3}, {"C", 0.1}])
      "A"

  """
  def choose(items) when is_list(items) do
    # Calculate the total weight
    total_weight = Enum.reduce(items, 0, fn {_, weight}, acc -> acc + weight end)

    # Generate a random number between 0 and total_weight
    random_number = :rand.uniform() * total_weight

    # Find the item with the corresponding weight
    find_item_by_weight(items, random_number, 0.0)
  end

  defp find_item_by_weight([], _, _), do: nil
  defp find_item_by_weight([{item, weight} | tail], random_number, current_weight) do
    new_weight = current_weight + weight
    if random_number < new_weight, do: item, else: find_item_by_weight(tail, random_number, new_weight)
  end
end
