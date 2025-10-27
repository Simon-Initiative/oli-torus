defmodule Oli.GoogleDocs.Markdown.Renderer do
  @moduledoc """
  Utilities for rendering Earmark AST fragments back into Markdown strings.
  Used by the Google Docs importer when we need to recreate the original
  markdown representation of table-based custom elements.
  """

  @inline_tags [
    "span",
    "strong",
    "em",
    "code",
    "a",
    "b",
    "i",
    "u",
    "sub",
    "sup",
    "del",
    "mark",
    "var",
    "img"
  ]
  @doc """
  Renders the children of a table cell AST node into a markdown string.
  """
  @spec render_cell_to_markdown(list()) :: String.t()
  def render_cell_to_markdown(children) do
    result =
      cond do
        inline_only?(children) ->
          render_inline(children)

        inline_paragraph_group?(children) ->
          children
          |> Enum.map(&render_paragraph_segment/1)
          |> Enum.reject(&(&1 == ""))
          |> join_segments_preserving_space()
          |> restore_placeholders()

        true ->
          children
          |> Enum.flat_map(&render_cell_child/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("\n\n")
          |> restore_placeholders()
      end

    result
    |> normalize_block_latex()
    |> String.trim()
  end

  defp render_cell_child(text) when is_binary(text) do
    content = restore_placeholders(text)

    if String.trim(content) == "" do
      []
    else
      [content]
    end
  end

  defp render_cell_child({"p", _attrs, children, _meta}) do
    case render_inline(children) do
      "" -> []
      inline -> [inline]
    end
  end

  defp render_cell_child({"ul", _attrs, items, _meta}) do
    [render_list(items, fn _index -> "- " end)]
  end

  defp render_cell_child({"ol", _attrs, items, _meta}) do
    [render_list(items, fn index -> Integer.to_string(index) <> ". " end)]
  end

  defp render_cell_child({"blockquote", _attrs, children, _meta}) do
    quoteds =
      children
      |> Enum.flat_map(&render_cell_child/1)
      |> Enum.flat_map(&String.split(&1, "\n"))
      |> Enum.map(&("> " <> &1))

    case quoteds do
      [] -> []
      _ -> [Enum.join(quoteds, "\n")]
    end
  end

  defp render_cell_child(
         {"pre", _attrs, [{"code", code_attrs, code_children, _meta_code}], _meta}
       ) do
    language =
      code_attrs
      |> Enum.into(%{})
      |> Map.get("class", "")
      |> String.replace_prefix("language-", "")
      |> String.trim()

    code = Enum.map(code_children, &render_plain_text/1) |> Enum.join()
    fence = "```"
    lang_segment = if language == "", do: "", else: language
    [Enum.join([fence <> lang_segment, code, fence], "\n")]
  end

  defp render_cell_child({"img", attrs, _children, _meta}) do
    attrs_map = Enum.into(attrs, %{})
    alt = attrs_map["alt"] || ""
    title = attrs_map["title"]
    src = attrs_map["src"] || ""

    image = ["![", alt, "](", src, render_image_title(title), ")"] |> IO.iodata_to_binary()

    case String.trim(image) do
      "" -> []
      content -> [content]
    end
  end

  defp render_cell_child({"a", attrs, [{"img", _img_attrs, _children, _} = img], _meta}) do
    img_attrs = Enum.into(attrs, %{})
    href = img_attrs["href"] || ""

    render_cell_child(img)
    |> Enum.map(fn image -> "[" <> image <> "](" <> href <> ")" end)
  end

  defp render_cell_child({tag, attrs, children, meta}) when tag in ["div", "section", "span"] do
    render_cell_child({"p", attrs, children, meta})
  end

  defp render_cell_child({tag, _attrs, children, _meta})
       when tag in ["tbody", "thead", "tr", "td"] do
    children
    |> Enum.flat_map(&render_cell_child/1)
  end

  defp render_cell_child({_tag, _attrs, children, _meta}) do
    children
    |> Enum.flat_map(&render_cell_child/1)
  end

  defp inline_only?(children) do
    Enum.all?(children, fn
      text when is_binary(text) -> true
      {"br", _, _, _} -> true
      {tag, _attrs, _children, _meta} -> inline_tag?(tag)
      _ -> false
    end)
  end

  defp inline_tag?(tag), do: tag in @inline_tags

  defp inline_paragraph_group?(children) do
    Enum.all?(children, fn
      {"p", _attrs, p_children, _meta} -> inline_only?(p_children)
      text when is_binary(text) -> String.trim(text) == ""
      _ -> false
    end)
  end

  defp render_paragraph_segment({"p", _attrs, children, _meta}) do
    render_inline(children)
  end

  defp render_paragraph_segment(text) when is_binary(text), do: restore_placeholders(text)
  defp render_paragraph_segment(_), do: ""

  defp join_segments_preserving_space(segments) do
    Enum.reduce(segments, "", fn segment, acc ->
      cond do
        acc == "" ->
          segment

        trailing_whitespace?(acc) or leading_whitespace?(segment) ->
          acc <> segment

        true ->
          acc <> " " <> segment
      end
    end)
  end

  defp trailing_whitespace?(string) do
    case String.last(string) do
      nil -> false
      char -> char in [" ", "\n", "\t"]
    end
  end

  defp leading_whitespace?(string) do
    case String.first(string) do
      nil -> false
      char -> char in [" ", "\n", "\t"]
    end
  end

  defp render_list(items, marker_fun) do
    items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn
      {{"li", _attrs, children, _meta}, index} ->
        render_list_item(children, marker_fun.(index))

      {other, index} ->
        render_list_item([other], marker_fun.(index))
    end)
    |> Enum.join("\n")
  end

  defp render_list_item(children, marker) do
    {inline_nodes, block_nodes} =
      Enum.split_with(children, &inline_candidate?/1)

    inline =
      inline_nodes
      |> Enum.map(&render_inline_node/1)
      |> Enum.join("")
      |> restore_placeholders()

    base_line =
      case String.trim(inline) do
        "" -> marker <> ""
        content -> marker <> content
      end

    nested =
      block_nodes
      |> Enum.flat_map(&render_cell_child/1)
      |> Enum.flat_map(&String.split(&1, "\n"))
      |> Enum.map(&("  " <> &1))

    [base_line | nested]
  end

  defp inline_candidate?(text) when is_binary(text), do: true

  defp inline_candidate?({tag, _attrs, _children, _meta}) do
    inline_tag?(tag) or tag == "p"
  end

  defp inline_candidate?(_), do: false

  defp render_inline(children) do
    children
    |> Enum.map(&render_inline_node/1)
    |> Enum.join("")
    |> restore_placeholders()
  end

  defp render_inline_node(text) when is_binary(text), do: restore_placeholders(text)

  defp render_inline_node({"strong", _attrs, children, _meta}) do
    "**" <> render_inline(children) <> "**"
  end

  defp render_inline_node({"em", _attrs, children, _meta}) do
    "*" <> render_inline(children) <> "*"
  end

  defp render_inline_node({"b", attrs, children, meta}) do
    render_inline_node({"strong", attrs, children, meta})
  end

  defp render_inline_node({"i", attrs, children, meta}) do
    render_inline_node({"em", attrs, children, meta})
  end

  defp render_inline_node({"code", _attrs, children, _meta}) do
    text = Enum.map(children, &render_plain_text/1) |> Enum.join()
    delimiter = if String.contains?(text, "`"), do: "``", else: "`"
    delimiter <> text <> delimiter
  end

  defp render_inline_node({"a", attrs, children, _meta}) do
    href = Enum.into(attrs, %{})["href"] || ""
    "[" <> render_inline(children) <> "](" <> href <> ")"
  end

  defp render_inline_node({"img", attrs, _children, _meta}) do
    attrs_map = Enum.into(attrs, %{})
    alt = attrs_map["alt"] || ""
    title = attrs_map["title"]
    src = attrs_map["src"] || ""
    "![" <> alt <> "](" <> src <> render_image_title(title) <> ")"
  end

  defp render_inline_node({"del", _attrs, children, _meta}) do
    "~~" <> render_inline(children) <> "~~"
  end

  defp render_inline_node({"sup", _attrs, children, _meta}) do
    "<sup>" <> render_inline(children) <> "</sup>"
  end

  defp render_inline_node({"sub", _attrs, children, _meta}) do
    "<sub>" <> render_inline(children) <> "</sub>"
  end

  defp render_inline_node({"u", _attrs, children, _meta}) do
    "<u>" <> render_inline(children) <> "</u>"
  end

  defp render_inline_node({"span", attrs, children, _meta}) do
    attrs_map = Enum.into(attrs, %{})
    styles = parse_style(attrs_map["style"])
    class_marks = parse_class_marks(attrs_map["class"])

    rendered = render_inline(children)

    rendered
    |> apply_span_mark(:bold, truthy?(styles[:bold] || class_marks[:bold]))
    |> apply_span_mark(:italic, truthy?(styles[:italic] || class_marks[:italic]))
    |> apply_span_mark(:underline, truthy?(styles[:underline] || class_marks[:underline]))
    |> apply_span_mark(
      :strikethrough,
      truthy?(styles[:strikethrough] || class_marks[:strikethrough])
    )
  end

  defp render_inline_node({"mark", _attrs, children, _meta}) do
    "<mark>" <> render_inline(children) <> "</mark>"
  end

  defp render_inline_node({"var", _attrs, children, _meta}) do
    "<var>" <> render_inline(children) <> "</var>"
  end

  defp render_inline_node({"br", _attrs, _children, _meta}), do: "  \n"

  defp render_inline_node({_tag, _attrs, children, _meta}) do
    render_inline(children)
  end

  defp render_plain_text(text) when is_binary(text), do: text

  defp render_plain_text({_tag, _attrs, children, _meta}) do
    children
    |> Enum.map(&render_plain_text/1)
    |> Enum.join()
  end

  defp render_plain_text(list) when is_list(list) do
    list
    |> Enum.map(&render_plain_text/1)
    |> Enum.join()
  end

  defp render_plain_text(_), do: ""

  defp render_image_title(nil), do: ""
  defp render_image_title(""), do: ""
  defp render_image_title(title), do: " \"" <> title <> "\""

  defp restore_placeholders(text) do
    text
    |> restore_inline_latex()
    |> restore_inline_directives()
  end

  defp normalize_block_latex(text) do
    text =
      Regex.replace(~r/(^|\n)\$\$(.+?)\$\$(?=\s*(\n|$))/s, text, fn _, prefix, inner ->
        normalized = inner |> String.trim()
        prefix <> "$$\n" <> normalized <> "\n$$"
      end)

    Regex.replace(~r/(^|\n)\\\[(.+?)\\\](?=\s*(\n|$))/s, text, fn _, prefix, inner ->
      normalized = inner |> String.trim()
      prefix <> "$$\n" <> normalized <> "\n$$"
    end)
  end

  defp restore_inline_latex(text) do
    Regex.replace(~r/INLINE_LATEX_START([A-Za-z0-9_\-]+)INLINE_LATEX_END/, text, fn _, encoded ->
      case Base.url_decode64(encoded, padding: false) do
        {:ok, decoded} -> "\\(" <> String.trim(decoded) <> "\\)"
        :error -> "\\(" <> encoded <> "\\)"
      end
    end)
  end

  defp restore_inline_directives(text) do
    Regex.replace(~r/INLINE_DIR_START_([^_]+)_([^_]+)_([^_]*)_INLINE_DIR_END/, text, fn _,
                                                                                        ename,
                                                                                        etext,
                                                                                        eattrs ->
      name = decode_base64(ename)
      directive_text = decode_base64(etext)
      attrs = decode_base64(eattrs)

      attr_segment =
        attrs
        |> String.trim()
        |> case do
          "" -> ""
          value -> "{" <> value <> "}"
        end

      ":" <> name <> "[" <> directive_text <> "]" <> attr_segment
    end)
  end

  defp decode_base64(encoded) do
    case Base.decode64(encoded, padding: false) do
      {:ok, decoded} -> decoded
      :error -> ""
    end
  end

  defp parse_style(nil), do: %{}
  defp parse_style(""), do: %{}

  defp parse_style(style_string) do
    style_string
    |> String.split(";", trim: true)
    |> Enum.reduce(%{}, fn declaration, acc ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] ->
          normalized_value = String.trim(value) |> String.downcase()

          case String.trim(property) |> String.downcase() do
            "font-weight" ->
              cond do
                normalized_value in ["bold", "700", "800", "900"] ->
                  Map.put(acc, :bold, true)

                true ->
                  acc
              end

            "font-style" ->
              if normalized_value == "italic" do
                Map.put(acc, :italic, true)
              else
                acc
              end

            "text-decoration" ->
              decorations =
                normalized_value
                |> String.split(" ", trim: true)
                |> MapSet.new()

              acc
              |> maybe_put_decoration(decorations, "underline", :underline)
              |> maybe_put_decoration(decorations, "line-through", :strikethrough)

            _ ->
              acc
          end

        _ ->
          acc
      end
    end)
  end

  defp maybe_put_decoration(acc, decorations, value, key) do
    if MapSet.member?(decorations, value) do
      Map.put(acc, key, true)
    else
      acc
    end
  end

  defp parse_class_marks(nil), do: %{}
  defp parse_class_marks(""), do: %{}

  defp parse_class_marks(class_string) do
    class_string
    |> String.split(~r/\s+/, trim: true)
    |> Enum.reduce(%{}, fn class, acc ->
      case String.downcase(class) do
        "bold" -> Map.put(acc, :bold, true)
        "italic" -> Map.put(acc, :italic, true)
        "underline" -> Map.put(acc, :underline, true)
        "strikethrough" -> Map.put(acc, :strikethrough, true)
        "line-through" -> Map.put(acc, :strikethrough, true)
        _ -> acc
      end
    end)
  end

  defp apply_span_mark(text, _mark, false), do: text

  defp apply_span_mark(text, :bold, true), do: "**" <> text <> "**"
  defp apply_span_mark(text, :italic, true), do: "*" <> text <> "*"
  defp apply_span_mark(text, :underline, true), do: "<u>" <> text <> "</u>"
  defp apply_span_mark(text, :strikethrough, true), do: "~~" <> text <> "~~"

  defp truthy?(value) when value in [nil, false], do: false
  defp truthy?(_), do: true
end
