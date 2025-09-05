defmodule Oli.TorusDoc.Markdown.TableParser do
  @moduledoc """
  Handles table parsing for TMD, converting GFM tables to Torus table elements.
  """

  alias Oli.TorusDoc.Markdown.InlineParser

  @doc """
  Parses a table from Earmark AST to Torus JSON.
  """
  def parse_table(table_children, directive_map) do
    {header_rows, body_rows} = split_table_sections(table_children)

    all_rows =
      transform_table_rows(header_rows, directive_map, true) ++
        transform_table_rows(body_rows, directive_map, false)

    %{
      "type" => "table",
      "children" => all_rows
    }
  end

  defp split_table_sections(children) do
    Enum.split_with(children, fn
      {"thead", _, _, _} -> true
      _ -> false
    end)
  end

  defp transform_table_rows([], _, _), do: []

  defp transform_table_rows(sections, directive_map, is_header) do
    sections
    |> Enum.flat_map(fn
      {"thead", _, rows, _} -> rows
      {"tbody", _, rows, _} -> rows
      {"tr", _, cells, meta} -> [{"tr", [], cells, meta}]
      _ -> []
    end)
    |> Enum.map(fn {"tr", _, cells, _} ->
      %{
        "type" => "tr",
        "children" => transform_table_cells(cells, directive_map, is_header)
      }
    end)
  end

  defp transform_table_cells(cells, directive_map, is_header) do
    Enum.map(cells, fn
      {"th", attrs, children, _} ->
        build_table_cell("th", attrs, children, directive_map)

      {"td", attrs, children, _} ->
        cell_type = if is_header, do: "th", else: "td"
        build_table_cell(cell_type, attrs, children, directive_map)

      _ ->
        nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_table_cell(type, attrs, children, directive_map) do
    attrs_map = attrs |> Enum.into(%{})

    cell = %{
      "type" => type,
      "children" => transform_cell_content(children, directive_map)
    }

    cell
    |> maybe_add_alignment(attrs_map)
    |> maybe_add_span(attrs_map)
  end

  defp transform_cell_content(children, directive_map) do
    # Table cells can contain inline content or block content
    case children do
      [{"p", _, _inline_children, _} | _] ->
        # If it starts with a paragraph, transform as block content
        transform_block_content(children, directive_map)

      _ ->
        # Otherwise, treat as inline content
        children
        |> Enum.flat_map(&InlineParser.transform(&1, directive_map))
        |> InlineParser.merge_adjacent_text()
    end
  end

  defp transform_block_content(children, directive_map) do
    children
    |> Enum.flat_map(fn
      {"p", _, inline_children, _} ->
        [
          %{
            "type" => "p",
            "children" =>
              inline_children
              |> Enum.flat_map(&InlineParser.transform(&1, directive_map))
              |> InlineParser.merge_adjacent_text()
          }
        ]

      other ->
        InlineParser.transform(other, directive_map)
    end)
  end

  defp maybe_add_alignment(cell, attrs_map) do
    case attrs_map["style"] do
      "text-align:left" -> Map.put(cell, "align", "left")
      "text-align:center" -> Map.put(cell, "align", "center")
      "text-align:right" -> Map.put(cell, "align", "right")
      _ -> cell
    end
  end

  defp maybe_add_span(cell, attrs_map) do
    cell
    |> maybe_add_attr("colspan", parse_span(attrs_map["colspan"]))
    |> maybe_add_attr("rowspan", parse_span(attrs_map["rowspan"]))
  end

  defp maybe_add_attr(map, _key, nil), do: map
  defp maybe_add_attr(map, key, value), do: Map.put(map, key, value)

  defp parse_span(nil), do: nil

  defp parse_span(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} when num > 1 -> num
      _ -> nil
    end
  end

  defp parse_span(value) when is_integer(value) and value > 1, do: value
  defp parse_span(_), do: nil
end
