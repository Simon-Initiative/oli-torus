defmodule Oli.Activities.ParseUtils do
  import Oli.Utils

  @doc """
  Takes a list of items that are either of the
  form {:ok, struct} or {:error, string} and if any
  errors are present it returns {:error, [string]}.
  If all entries are {:ok, struct} then this
  returns {:ok, [struct]}
  """
  def items_or_errors(items) do
    if Enum.any?(items, fn {mark, _} -> mark == :error end) do
      {:error,
       Enum.filter(items, fn {mark, _} -> mark == :error end)
       |> Enum.map(fn {_, error} -> error end)
       |> List.flatten()}
    else
      {:ok,
       Enum.filter(items, fn {mark, _} -> mark == :ok end)
       |> Enum.map(fn {_, item} -> item end)}
    end
  end

  @doc """
  Filters out slate items with no "real" content. E.g.,
  # %{
  #   "content" => %{
  #     "model" => [
  #       %{"children" => [%{"text" => ""}], "type" => "p"}
  #     ]
  #   }
  # }
  """
  def remove_empty(items) do
    Enum.filter(items, &has_content?(&1))
  end

  # The model is stored using atoms or strings depending on where it is in the system
  def has_content?(%{content: %{model: model}}), do: has_content?(model)
  def has_content?(%{content: %{"model" => model}}), do: has_content?(model)
  def has_content?(%{"content" => %{"model" => model}}), do: has_content?(model)
  # The model has content if it's not a paragraph node with no trimmed text.
  def has_content?([%{"children" => [%{"text" => text} | _], "type" => "p"} | _]),
    do: String.trim(text) != ""

  def has_content?(_model), do: true

  def default_content_item(text) when is_binary(text) do
    %{
      content: %{
        "model" => [
          %{"children" => [%{"text" => text}], "id" => uuid(), "type" => "p"}
        ],
        "selection" => nil
      },
      id: uuid()
    }
  end
end
