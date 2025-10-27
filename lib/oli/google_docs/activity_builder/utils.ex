defmodule Oli.GoogleDocs.ActivityBuilder.Utils do
  @moduledoc """
  Shared helper functions for Google Docs activity builders.
  """

  alias Oli.TorusDoc.Markdown.MarkdownParser

  @default_hint_count 3

  @spec unique_id() :: String.t()
  def unique_id do
    :erlang.unique_integer([:monotonic, :positive])
    |> Integer.to_string()
  end

  @spec make_content_map(String.t()) :: map()
  def make_content_map(text) do
    %{
      "id" => unique_id(),
      "content" => rich_text(text || ""),
      "editor" => "slate",
      "textDirection" => "ltr"
    }
  end

  @spec rich_text(String.t()) :: list()
  def rich_text(text) do
    case MarkdownParser.parse(text || "") do
      {:ok, content} ->
        content
        |> cleanup_formula_artifacts()
        |> normalize_formulas()

      {:error, _reason} ->
        [
          %{
            "type" => "p",
            "children" => [
              %{"text" => text || ""}
            ]
          }
        ]
    end
  end

  @spec empty_feedback() :: map()
  def empty_feedback do
    make_content_map("")
  end

  @spec parse_hints(list(), keyword()) :: list(map())
  def parse_hints(raw_rows, opts \\ []) do
    default_count = Keyword.get(opts, :default_count, @default_hint_count)

    hints =
      raw_rows
      |> Enum.reduce([], fn {key, value}, acc ->
        case parse_indexed_key(key, "hint") do
          {:ok, index} ->
            text = value |> to_string() |> String.trim()

            if text == "" do
              acc
            else
              [{index, make_content_map(text)} | acc]
            end

          :error ->
            acc
        end
      end)
      |> Enum.sort_by(fn {index, _} -> index end)
      |> Enum.map(fn {_index, hint} -> hint end)

    needed = max(default_count - length(hints), 0)
    hints ++ Enum.map(1..needed, fn _ -> make_content_map("") end)
  end

  @spec parse_indexed_key(any(), String.t()) :: {:ok, integer()} | :error
  def parse_indexed_key(key, prefix) when is_binary(key) do
    downcased = String.downcase(key)

    if String.starts_with?(downcased, prefix) do
      suffix = String.replace_prefix(downcased, prefix, "")

      if suffix != "" and Regex.match?(~r/^\d+$/, suffix) do
        {:ok, String.to_integer(suffix)}
      else
        :error
      end
    else
      :error
    end
  end

  def parse_indexed_key(_, _), do: :error

  defp cleanup_formula_artifacts(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&cleanup_formula_artifacts/1)
    |> cleanup_adjacent_formula_text([])
    |> Enum.reverse()
  end

  defp cleanup_formula_artifacts(%{"children" => children} = node) do
    %{node | "children" => cleanup_formula_artifacts(children)}
  end

  defp cleanup_formula_artifacts(node), do: node

  defp cleanup_adjacent_formula_text([], acc), do: acc

  defp cleanup_adjacent_formula_text(
         [%{"text" => text} = node | rest = [%{"type" => "formula_inline"} | _]],
         acc
       ) do
    cond do
      blank_or_backslash?(text) ->
        cleanup_adjacent_formula_text(rest, acc)

      String.ends_with?(text, "\\") ->
        updated = %{node | "text" => String.trim_trailing(text, "\\")}
        cleanup_adjacent_formula_text([updated | rest], acc)

      true ->
        cleanup_adjacent_formula_text(rest, [node | acc])
    end
  end

  defp cleanup_adjacent_formula_text(
         [%{"type" => "formula_inline"} = formula, %{"text" => text} = node | rest],
         acc
       ) do
    cond do
      blank_or_backslash?(text) ->
        cleanup_adjacent_formula_text(rest, [formula | acc])

      String.starts_with?(text, "\\") ->
        updated = %{node | "text" => String.trim_leading(text, "\\")}
        cleanup_adjacent_formula_text([formula, updated | rest], acc)

      true ->
        cleanup_adjacent_formula_text(rest, [node, formula | acc])
    end
  end

  defp cleanup_adjacent_formula_text([node | rest], acc) do
    cleanup_adjacent_formula_text(rest, [node | acc])
  end

  defp blank_or_backslash?(text) do
    trimmed = String.trim(to_string(text))
    trimmed == "" or trimmed == "\\"
  end

  defp normalize_formulas(nodes) when is_list(nodes) do
    Enum.map(nodes, &normalize_formulas/1)
  end

  defp normalize_formulas(%{"type" => type} = node) when type in ["formula_inline", "formula"] do
    children =
      node
      |> Map.get("children", [%{"text" => ""}])
      |> normalize_formulas()

    Map.put(node, "children", children)
  end

  defp normalize_formulas(%{"children" => children} = node) do
    Map.put(node, "children", normalize_formulas(children))
  end

  defp normalize_formulas(node), do: node
end