defmodule Oli.Activities.ParseUtils do

  @doc """
  Takes a list of items that are either of the
  form {:ok, struct} or {:error, string} and if any
  errors are present it returns {:error, [string]}.
  If all entries are {:ok, struct} then this
  returns {:ok, [struct]}
  """
  def items_or_errors(items) do
    if Enum.any?(items, fn {mark, _} -> mark == :error end) do
      {:error, Enum.filter(items, fn {mark, _} -> mark == :error end)
      |> Enum.map(fn {_, error} -> error end)
      |> List.flatten()}
    else
      {:ok, Enum.filter(items, fn {mark, _} -> mark == :ok end)
      |> Enum.map(fn {_, item} -> item end)}
    end
  end


end
