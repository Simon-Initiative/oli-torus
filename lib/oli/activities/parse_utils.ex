defmodule Oli.Activities.ParseUtils do
  alias Oli.Rendering
  alias Oli.Rendering.Context

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

  @doc """
  Filters out items with no content
  """
  def remove_empty({:error, _} = items), do: items
  def remove_empty({:ok, items}) do
    {:ok, Enum.filter(items, & has_content?(&1))}
  end
  def has_content?(%{content: content} = here) do
    IO.inspect(here, label: "here")
    text = Rendering.Content.render(%Context{}, content, Rendering.Content.Plaintext)
    |> Enum.join("")
    IO.inspect(text, label: "text")
    case String.trim(text) do
      "" -> false
      _ -> true
    end
  end
end
