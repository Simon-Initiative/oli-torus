defmodule Oli.Resources.Alternatives.OptionOrder do
  @moduledoc """
  Reorders alternatives options without changing their stable identifiers.
  """

  @doc """
  Moves an option to a drop target index.

  Drop indexes identify the gap before an option, with the final index identifying
  the gap after the last option.
  """
  @spec move_to([map()], String.t(), integer()) ::
          {:ok, [map()] | :unchanged} | {:error, :invalid_reorder}
  def move_to(options, option_id, drop_index)
      when is_integer(drop_index) and drop_index >= 0 do
    with true <- drop_index <= length(options),
         source_index when is_integer(source_index) <-
           Enum.find_index(options, &(&1["id"] == option_id)) do
      insert_index = if source_index < drop_index, do: drop_index - 1, else: drop_index
      option = Enum.at(options, source_index)

      reordered_options =
        options
        |> List.delete_at(source_index)
        |> List.insert_at(insert_index, option)

      if reordered_options == options, do: {:ok, :unchanged}, else: {:ok, reordered_options}
    else
      _ -> {:error, :invalid_reorder}
    end
  end

  def move_to(_options, _option_id, _drop_index), do: {:error, :invalid_reorder}
end
