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
  def remove_empty(items) do
    Enum.filter(items, & has_content?(&1))
  end

  # The model is stored using atoms or strings depending on where it is in the system
  def has_content?(%{content: %{ model: model }}), do: has_content?(model)
  def has_content?(%{content: %{ "model" => model }}), do: has_content?(model)
  def has_content?(%{"content" => %{ "model" => model }}), do: has_content?(model)
  def has_content?(model) do
    plaintext_content = Rendering.Content.render(%Context{}, model, Rendering.Content.Plaintext)
    |> Enum.join("")
    |> String.trim()
    case plaintext_content do
      "" -> false
      _ -> true
    end
  end
end
