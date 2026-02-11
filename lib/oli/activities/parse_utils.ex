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
  ```
    %{
      "content" => %{
        "model" => [
          %{"children" => [%{"text" => ""}], "type" => "p"}
        ]
      }
    }
  ```
  """
  def remove_empty(nil), do: []
  def remove_empty(items), do: Enum.filter(items, &has_content?/1)

  # The model is stored using atoms or strings depending on where it is in the system
  def has_content?(nil), do: false

  def has_content?(xs) do
    case xs do
      # a list under the "content" or "children" key.
      # if any child has content, the parent has content
      xs when is_list(xs) ->
        Enum.any?(for x <- xs, do: has_content?(x))

      # These elements ARE content, even if they don't have children or text in them.
      %{"type" => t}
      when t in [
             "img",
             "img_inline",
             "conjugation",
             "dialog",
             "definition",
             "formula",
             "formula_inline",
             "youtube",
             "audio",
             "iframe",
             "video"
           ] ->
        true

      %{content: content} ->
        case content do
          # :model -> former impl when selection was persisted
          # along with the model
          %{"model" => model} ->
            has_content?(model)

          %{model: model} ->
            has_content?(model)

          # should be a list otherwise
          xs ->
            has_content?(xs)
        end

      %{"content" => content} ->
        case content do
          # "model" -> former impl when selection was persisted
          # along with the model
          %{"model" => model} ->
            has_content?(model)

          # should be a list otherwise
          xs ->
            has_content?(xs)
        end

      %{"children" => xs} ->
        has_content?(xs)

      # Slate leaf node -> check for content directly
      %{"text" => text} ->
        String.trim(text) != ""

      %{"type" => "p", "children" => xs} ->
        has_content?(xs)

      # unexpected structure -- assume there's content
      _ ->
        true
    end
  end
end
