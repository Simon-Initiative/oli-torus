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
end
