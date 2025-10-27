defmodule Oli.GoogleDocs.MarkdownParser do
  @moduledoc """
  Converts Google Docs Markdown exports into intermediate blocks, custom element
  specifications, and embedded media descriptors for downstream ingestion.

  The parser walks the Earmark AST while preserving block ordering, inline marks,
  custom element table data, and data URL-backed images. It emits a structured
  result consumed by later phases of the import pipeline.
  """

  alias Oli.GoogleDocs.Warnings

  @default_max_nodes 50_000
  @earmark_options %Earmark.Options{
    gfm: true,
    breaks: false,
    smartypants: false,
    pure_links: false
  }
  @inline_latex_pattern ~r/\\\((.+?)\\\)/s
  @inline_latex_start "INLINE_LATEX_START"
  @inline_latex_end "INLINE_LATEX_END"

  defmodule Result do
    @moduledoc """
    Structured output from the Markdown parser.
    """

    @enforce_keys [:blocks, :custom_elements, :media, :warnings]
    defstruct blocks: [],
              custom_elements: [],
              media: [],
              warnings: [],
              title: nil
  end

  defmodule CustomElement do
    @moduledoc """
    Representation of a detected CustomElement table.
    """

    @enforce_keys [:id, :element_type, :data, :raw_rows, :block_index]
    defstruct [:id, :element_type, :data, :raw_rows, :block_index]
  end

  defmodule MediaReference do
    @moduledoc """
    Description of an embedded image discovered during parsing.
    """

    @enforce_keys [:id, :src, :alt, :title, :origin, :block_index]
    defstruct [:id, :src, :alt, :title, :origin, :mime_type, :data, :filename, :block_index]
  end

  defmodule State do
    @moduledoc false

    defstruct blocks: [],
              custom_elements: [],
              media: [],
              warnings: [],
              block_index: 0,
              next_custom_id: 1,
              next_media_id: 1,
              metadata: %{}
  end

  @type parse_option ::
          {:metadata, map()}
          | {:max_nodes, pos_integer()}

  @doc """
  Parses Markdown into structured blocks, custom element specs, and media references.
  """
  @spec parse(binary(), [parse_option()]) :: {:ok, Result.t()} | {:error, atom(), list(map())}
  def parse(markdown, opts \\ [])

  def parse(markdown, opts) when is_binary(markdown) do
    metadata = opts |> Keyword.get(:metadata, %{}) |> normalize_metadata()
    max_nodes = Keyword.get(opts, :max_nodes, @default_max_nodes)

    markdown = encode_inline_latex(markdown)

    case Earmark.Parser.as_ast(markdown, @earmark_options) do
      {:ok, ast, messages} ->
        build_result(ast, messages, metadata, max_nodes)

      {:error, ast, messages} ->
        build_result(ast, messages, metadata, max_nodes, error?: true)
    end
  end

  def parse(_, opts) do
    parse("", opts)
  end

  defp build_result(ast, messages, metadata, max_nodes, opts \\ []) do
    warnings =
      messages
      |> Enum.map(&earmark_message_to_warning/1)
      |> Enum.filter(& &1)

    cond do
      count_nodes(ast) > max_nodes ->
        warning =
          Warnings.build(:markdown_parse_error, %{
            context: "AST node count (#{count_nodes(ast)}) exceeded limit #{max_nodes}"
          })

        {:error, :document_too_complex, [warning | warnings]}

      true ->
        initial_state = %State{metadata: metadata, warnings: warnings}

        state =
          ast
          |> Enum.reduce(initial_state, fn node, acc -> append_blocks(node, acc) end)

        blocks =
          state.blocks
          |> Enum.reverse()

        custom_elements =
          state.custom_elements
          |> Enum.reverse()

        media =
          state.media
          |> Enum.reverse()

        title =
          metadata[:title] ||
            extract_title_from_blocks(blocks) ||
            metadata[:fallback_title]

        result = %Result{
          blocks: blocks,
          custom_elements: custom_elements,
          media: media,
          warnings: state.warnings |> Enum.reverse(),
          title: title
        }

        case opts[:error?] do
          true -> {:ok, result}
          _ -> {:ok, result}
        end
    end
  end

  defp append_blocks(node, state) do
    {blocks, state} = build_blocks(node, state)

    Enum.reduce(blocks, state, fn block, acc -> add_block(acc, block) end)
  end

  defp build_blocks({tag, _attrs, _children, _meta} = node, state) do
    case tag do
      "h1" -> heading_block(node, state, 1)
      "h2" -> heading_block(node, state, 2)
      "h3" -> heading_block(node, state, 3)
      "h4" -> heading_block(node, state, 4)
      "h5" -> heading_block(node, state, 5)
      "h6" -> heading_block(node, state, 6)
      "p" -> paragraph_block(node, state)
      "ul" -> list_block(node, state, :unordered_list)
      "ol" -> list_block(node, state, :ordered_list)
      "blockquote" -> blockquote_block(node, state)
      "pre" -> preformatted_block(node, state)
      "table" -> table_block(node, state)
      "hr" -> {[], state}
      _ -> unsupported_block(node, state, tag)
    end
  end

  defp build_blocks(text, state) when is_binary(text) do
    case String.trim(text) do
      "" ->
        {[], state}

      content ->
        block = %{
          type: :paragraph,
          inlines: [%{text: content, marks: [], href: nil}],
          index: state.block_index
        }

        {[block], state}
    end
  end

  defp heading_block({"h" <> _ = _tag, _attrs, children, _meta}, state, level) do
    inlines = parse_inlines(children)

    block = %{
      type: :heading,
      level: level,
      inlines: inlines,
      index: state.block_index
    }

    {[block], state}
  end

  defp paragraph_block({"p", _attrs, children, _meta}, state) do
    case detect_block_math(children) do
      {:math, latex} ->
        {[%{type: :formula, src: latex}], state}

      nil ->
        case extract_single_image(children) do
          {:image, attrs} ->
            build_image_block(attrs, state)

          :not_image ->
            inlines = parse_inlines(children)

            if Enum.empty?(inlines) do
              {[], state}
            else
              block = %{
                type: :paragraph,
                inlines: inlines,
                index: state.block_index
              }

              {[block], state}
            end
        end
    end
  end

  defp list_block({_tag, _attrs, children, _meta}, state, list_type) do
    {items, state} =
      Enum.reduce(children, {[], state}, fn
        {"li", _attrs, li_children, _meta}, {acc_items, acc_state} ->
          {nested_lists, inline_children} = partition_list_children(li_children)
          inlines = parse_inlines(inline_children)
          {nested_blocks, updated_state} = build_nested_list_blocks(nested_lists, acc_state)
          item = %{inlines: inlines, nested: nested_blocks}
          {[item | acc_items], updated_state}

        other, {acc_items, acc_state} ->
          inlines = parse_inlines([other])
          {[%{inlines: inlines, nested: []} | acc_items], acc_state}
      end)

    items = Enum.reverse(items)

    block = %{
      type: list_type,
      items: items,
      index: state.block_index
    }

    {[block], state}
  end

  defp blockquote_block({"blockquote", _attrs, children, _meta}, state) do
    {nested_blocks, state} =
      Enum.reduce(children, {[], state}, fn child, {acc_blocks, acc_state} ->
        {blocks, new_state} = build_blocks(child, acc_state)
        {acc_blocks ++ blocks, new_state}
      end)

    block = %{
      type: :blockquote,
      blocks: nested_blocks,
      index: state.block_index
    }

    {[block], state}
  end

  defp preformatted_block({"pre", _attrs, inner, _meta}, state) do
    code_block =
      case inner do
        [{"code", attributes, [code], _}] ->
          language =
            attributes
            |> Enum.find_value("text", fn {key, value} ->
              if key == "class" do
                value
                |> String.replace_prefix("language-", "")
              end
            end)

          %{
            type: :code,
            language: language,
            code: code,
            index: state.block_index
          }

        _ ->
          %{
            type: :code,
            language: "text",
            code: extract_plain_text(inner),
            index: state.block_index
          }
      end

    {[code_block], state}
  end

  defp table_block({"table", _attrs, children, _meta}, state) do
    case extract_custom_element(children) do
      {:ok, element_type, rows} ->
        id = "custom-element-#{state.next_custom_id}"
        data = Map.new(rows)

        custom_element = %CustomElement{
          id: id,
          element_type: String.downcase(element_type),
          data: data,
          raw_rows: rows,
          block_index: state.block_index
        }

        block = %{
          type: :custom_element_placeholder,
          id: id,
          element_type: custom_element.element_type,
          index: state.block_index
        }

        new_state =
          state
          |> Map.update!(:next_custom_id, &(&1 + 1))
          |> Map.update!(:custom_elements, &[custom_element | &1])

        {[block], new_state}

      {:error, :invalid_shape, element_type} ->
        warning =
          Warnings.build(:custom_element_invalid_shape, %{
            element_type: element_type || "unknown"
          })

        state = Map.update!(state, :warnings, &[warning | &1])

        build_table_block(children, state)

      {:error, :no_match} ->
        build_table_block(children, state)
    end
  end

  defp unsupported_block({_tag, _attrs, _children, _meta}, state, tag) do
    warning =
      Warnings.build(:unsupported_block, %{
        block_type: tag
      })

    {[], Map.update!(state, :warnings, &[warning | &1])}
  end

  defp build_table_block(children, state) do
    header = parse_table_header(children)
    rows = parse_table_rows(children)

    block = %{
      type: :table,
      header: header,
      rows: rows,
      index: state.block_index
    }

    {[block], state}
  end

  defp parse_table_header(children) do
    children
    |> Enum.find(fn
      {"thead", _, _, _} -> true
      _ -> false
    end)
    |> case do
      nil ->
        []

      {"thead", _, thead_children, _} ->
        thead_children
        |> Enum.flat_map(fn
          {"tr", _, cells, _} ->
            Enum.map(cells, fn cell ->
              parse_inlines(elem(cell, 2))
            end)

          _ ->
            []
        end)
    end
  end

  defp parse_table_rows(children) do
    children
    |> Enum.flat_map(fn
      {"tbody", _, body_rows, _} ->
        Enum.map(body_rows, fn
          {"tr", _, cells, _} ->
            Enum.map(cells, fn cell ->
              parse_inlines(elem(cell, 2))
            end)

          _ ->
            []
        end)

      {"tr", _, cells, _} ->
        [
          Enum.map(cells, fn cell ->
            parse_inlines(elem(cell, 2))
          end)
        ]

      _ ->
        []
    end)
  end

  defp extract_custom_element(children) do
    case locate_custom_element_header(children) do
      {:ok, {header_cells, body_rows}} ->
        with [first_header, second_header | _] <- header_cells,
             first_text <-
               extract_plain_text(header_children(first_header))
               |> String.trim(),
             second_text <-
               extract_plain_text(header_children(second_header))
               |> String.trim(),
             "customelement" <- String.downcase(first_text),
             type when type != "" <- second_text do
          rows =
            body_rows
            |> Enum.map(&parse_custom_row/1)
            |> Enum.filter(fn
              {nil, _} -> false
              {_, nil} -> false
              {k, v} -> k != "" and v != ""
            end)

          if rows == [] do
            {:error, :invalid_shape, type}
          else
            {:ok, type, rows}
          end
        else
          _ ->
            {:error, :no_match}
        end

      :error ->
        {:error, :no_match}
    end
  end

  defp locate_custom_element_header(children) do
    case Enum.find(children, &match?({"thead", _, _, _}, &1)) do
      {"thead", _, [{"tr", _, header_cells, _}], _} = _thead ->
        body_rows = extract_tbody_rows(children)
        {:ok, {header_cells, body_rows}}

      _ ->
        case extract_tbody_rows_with_header(children) do
          {:ok, header_cells, body_rows} -> {:ok, {header_cells, body_rows}}
          :error -> :error
        end
    end
  end

  defp extract_tbody_rows(children) do
    children
    |> Enum.find(&match?({"tbody", _, _, _}, &1))
    |> case do
      nil -> []
      {"tbody", _, body_rows, _} -> body_rows
    end
  end

  defp extract_tbody_rows_with_header(children) do
    case Enum.find(children, &match?({"tbody", _, _, _}, &1)) do
      {"tbody", _, [first_row | rest], _} = _tbody ->
        header_cells = extract_row_cells(first_row)

        if header_cells != [] do
          {:ok, header_cells, rest}
        else
          :error
        end

      _ ->
        :error
    end
  end

  defp extract_row_cells({"tr", _, cells, _}), do: cells
  defp extract_row_cells(_), do: []

  defp parse_custom_row({"tr", _, [key_cell, value_cell], _}) do
    key = extract_plain_text(cell_children(key_cell)) |> String.trim()
    value = render_cell_to_markdown(cell_children(value_cell))
    {key, value}
  end

  defp parse_custom_row({"tr", _, cells, _}) when length(cells) >= 2 do
    key = extract_plain_text(cell_children(Enum.at(cells, 0))) |> String.trim()
    value = render_cell_to_markdown(cell_children(Enum.at(cells, 1)))
    {key, value}
  end

  defp parse_custom_row(_), do: {nil, nil}

  defp header_children({tag, _attrs, children, _meta}) when tag in ["th", "td"], do: children
  defp header_children({_tag, _attrs, children, _meta}), do: children

  defp cell_children({tag, _attrs, children, _meta}) when tag in ["td", "th"], do: children
  defp cell_children({_tag, _attrs, children, _meta}), do: children

  defp render_cell_to_markdown(children) do
    children
    |> Enum.flat_map(&render_cell_child/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> restore_placeholders()
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
    tag in ["p", "span", "strong", "em", "code", "a", "b", "i", "u", "sub", "sup", "del", "mark"]
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

  defp render_inline_node({"span", _attrs, children, _meta}) do
    render_inline(children)
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

  defp extract_single_image(children) do
    non_whitespace_children =
      Enum.reject(children, fn
        text when is_binary(text) -> String.trim(text) == ""
        _ -> false
      end)

    case non_whitespace_children do
      [{"img", attrs, _children, _meta}] ->
        {:image, attrs}

      [{"a", _attrs, [{"img", attrs, _children, _meta_img}], _meta_link}] ->
        {:image, attrs}

      _ ->
        :not_image
    end
  end

  defp build_image_block(attrs, state) do
    attr_map = Enum.into(attrs, %{})
    src = Map.get(attr_map, "src", "")
    alt = Map.get(attr_map, "alt", "")
    title = Map.get(attr_map, "title", "")

    {origin, meta, state} = classify_image_source(src, state, title || alt)

    id = "media-#{state.next_media_id}"

    media_reference = %MediaReference{
      id: id,
      src: src,
      alt: alt,
      title: title,
      origin: origin,
      mime_type: Map.get(meta, :mime_type),
      data: Map.get(meta, :data),
      filename: Map.get(meta, :filename),
      block_index: state.block_index
    }

    block = %{
      type: :image,
      media_id: id,
      alt: alt,
      title: title,
      origin: origin,
      index: state.block_index
    }

    new_state =
      state
      |> Map.update!(:media, &[media_reference | &1])
      |> Map.update!(:next_media_id, &(&1 + 1))

    {[block], new_state}
  end

  defp classify_image_source(src, state, label) do
    cond do
      String.starts_with?(src, "data:") ->
        case parse_data_url(src) do
          {:ok, %{mime_type: mime, data: data}} ->
            {:data_url, %{mime_type: mime, data: data}, state}

          :error ->
            warning =
              Warnings.build(:media_decode_failed, %{
                filename: label || "inline image"
              })

            {:data_url, %{mime_type: nil, data: nil},
             Map.update!(state, :warnings, &[warning | &1])}
        end

      true ->
        {:remote, %{}, state}
    end
  end

  defp parse_data_url(url) do
    with "data:" <> rest <- url,
         [meta, base64] <- String.split(rest, ",", parts: 2),
         true <- String.contains?(meta, ";base64"),
         [mime_type | _] <- String.split(meta, ";"),
         true <- base64 != "" do
      {:ok, %{mime_type: mime_type, data: base64}}
    else
      _ -> :error
    end
  end

  defp parse_inlines(children) when is_list(children) do
    children
    |> Enum.flat_map(&parse_inline_element(&1, []))
    |> merge_adjacent_inlines()
  end

  defp parse_inline_element(text, marks) when is_binary(text) do
    text
    |> split_inline_latex_segments()
    |> Enum.flat_map(fn
      {:text, ""} ->
        []

      {:text, content} ->
        [%{text: content, marks: marks, href: nil}]

      {:latex, content} ->
        [%{type: :inline_formula, src: content}]
    end)
  end

  defp parse_inline_element({"strong", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:strong | marks])
  end

  defp parse_inline_element({"b", attrs, children, meta}, marks),
    do: parse_inline_element({"strong", attrs, children, meta}, marks)

  defp parse_inline_element({"em", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:em | marks])
  end

  defp parse_inline_element({"i", attrs, children, meta}, marks),
    do: parse_inline_element({"em", attrs, children, meta}, marks)

  defp parse_inline_element({"code", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:code | marks])
  end

  defp parse_inline_element({"mark", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:mark | marks])
  end

  defp parse_inline_element({"del", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:del | marks])
  end

  defp parse_inline_element({"s", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:strikethrough | marks])
  end

  defp parse_inline_element({"strike", attrs, children, meta}, marks),
    do: parse_inline_element({"s", attrs, children, meta}, marks)

  defp parse_inline_element({"var", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:var | marks])
  end

  defp parse_inline_element({"dfn", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:term | marks])
  end

  defp parse_inline_element({"sub", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:sub | marks])
  end

  defp parse_inline_element({"sup", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:sup | marks])
  end

  defp parse_inline_element({"u", _attrs, children, _meta}, marks) do
    parse_inlines(children, [:underline | marks])
  end

  defp parse_inline_element({"a", attrs, children, _meta}, marks) do
    href = Enum.find_value(attrs, fn {key, value} -> key == "href" && value end)

    children
    |> parse_inlines(marks)
    |> Enum.map(fn inline -> Map.put(inline, :href, href) end)
  end

  defp parse_inline_element({"span", _attrs, children, _meta}, marks) do
    parse_inlines(children, marks)
  end

  defp parse_inline_element({"br", _attrs, _children, _meta}, marks) do
    [%{text: "\n", marks: marks, href: nil}]
  end

  defp parse_inline_element({"img", _attrs, _children, _meta}, _marks) do
    []
  end

  defp parse_inline_element({_tag, _attrs, children, _meta}, marks) do
    parse_inlines(children, marks)
  end

  defp split_inline_latex_segments(text), do: split_inline_latex_segments(text, [])

  defp split_inline_latex_segments("", acc), do: Enum.reverse(acc)

  defp split_inline_latex_segments(text, acc) do
    case :binary.match(text, @inline_latex_start) do
      :nomatch ->
        finalize_text_segment(text, acc)

      {start, start_len} ->
        before = binary_part(text, 0, start)
        after_open = start + start_len
        remaining = binary_part(text, after_open, byte_size(text) - after_open)

        case :binary.match(remaining, @inline_latex_end) do
          :nomatch ->
            finalize_text_segment(text, acc)

          {close_rel, end_len} ->
            encoded = binary_part(remaining, 0, close_rel)
            after_close = close_rel + end_len

            trailing =
              binary_part(remaining, after_close, byte_size(remaining) - after_close)

            acc =
              acc
              |> prepend_text(before)
              |> prepend_latex(encoded)

            split_inline_latex_segments(trailing, acc)
        end
    end
  end

  defp finalize_text_segment("", acc), do: Enum.reverse(acc)
  defp finalize_text_segment(text, acc), do: Enum.reverse(prepend_text(acc, text))

  defp prepend_text(acc, ""), do: acc
  defp prepend_text(acc, text), do: [{:text, text} | acc]

  defp prepend_latex(acc, encoded) do
    with {:ok, decoded} <- Base.url_decode64(encoded, padding: false),
         normalized <- normalize_inline_latex(decoded),
         true <- normalized != "" do
      [{:latex, normalized} | acc]
    else
      _ -> [{:text, "\\(" <> decode_placeholder(encoded) <> "\\)"} | acc]
    end
  end

  defp encode_inline_latex(markdown) do
    Regex.replace(@inline_latex_pattern, markdown, fn _match, inner ->
      inner
      |> normalize_inline_latex()
      |> String.trim_trailing("\\")
      |> Base.url_encode64(padding: false)
      |> then(&(@inline_latex_start <> &1 <> @inline_latex_end))
    end)
  end

  defp normalize_inline_latex(content) do
    content
    |> String.trim()
    |> String.replace("\\\\", "\\")
  end

  defp decode_placeholder(encoded) do
    case Base.url_decode64(encoded, padding: false) do
      {:ok, decoded} -> decoded
      :error -> encoded
    end
  end

  defp parse_inlines(children, marks) do
    children
    |> Enum.flat_map(&parse_inline_element(&1, marks))
  end

  defp merge_adjacent_inlines(inlines) do
    Enum.reduce(inlines, [], fn inline, acc ->
      case acc do
        [%{text: text, marks: marks, href: href} = head | tail]
        when marks == inline.marks and href == inline.href ->
          [%{head | text: text <> inline.text} | tail]

        _ ->
          [inline | acc]
      end
    end)
    |> Enum.reverse()
  end

  defp partition_list_children(children) do
    Enum.split_with(children, fn
      {"ul", _, _, _} -> true
      {"ol", _, _, _} -> true
      _ -> false
    end)
  end

  defp build_nested_list_blocks(nested_lists, state) do
    Enum.reduce(nested_lists, {[], state}, fn node, {acc_blocks, acc_state} ->
      {blocks, new_state} = build_blocks(node, acc_state)
      {acc_blocks ++ blocks, new_state}
    end)
  end

  defp extract_plain_text(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&extract_plain_text/1)
    |> Enum.join()
  end

  defp extract_plain_text(text) when is_binary(text), do: text

  defp extract_plain_text({tag, _attrs, children, _meta})
       when tag in ["strong", "em", "span", "code"] do
    extract_plain_text(children)
  end

  defp extract_plain_text({_, _, children, _}) do
    extract_plain_text(children)
  end

  defp detect_block_math(children) do
    text =
      children
      |> extract_plain_text()
      |> String.trim()

    case Regex.run(~r/^\$\$\s*(.*?)\s*\$\$/s, text) do
      [_, latex] -> {:math, latex}
      _ -> nil
    end
  end

  defp add_block(state, block) do
    block_with_index =
      Map.put(block, :index, state.block_index)

    %State{
      state
      | blocks: [block_with_index | state.blocks],
        block_index: state.block_index + 1
    }
  end

  defp normalize_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.reduce(%{}, fn
      {key, value}, acc when key in [:title, "title"] ->
        Map.put(acc, :title, value)

      {key, value}, acc when key in [:fallback_title, "fallback_title"] ->
        Map.put(acc, :fallback_title, value)

      _, acc ->
        acc
    end)
  end

  defp normalize_metadata(_), do: %{}

  defp extract_title_from_blocks(blocks) do
    blocks
    |> Enum.find_value(fn
      %{type: :heading, level: 1, inlines: inlines} ->
        inlines
        |> Enum.map(& &1.text)
        |> Enum.join()
        |> String.trim()
        |> case do
          "" -> nil
          text -> text
        end

      _ ->
        nil
    end)
  end

  defp count_nodes(ast) when is_list(ast) do
    Enum.reduce(ast, 0, fn node, acc -> acc + count_nodes(node) end)
  end

  defp count_nodes({_tag, _attrs, children, _meta}) do
    1 + count_nodes(children)
  end

  defp count_nodes(text) when is_binary(text), do: 1

  defp count_nodes(_), do: 1

  defp earmark_message_to_warning({severity, line, message}) do
    if String.contains?(message, "messages is an internal option") do
      nil
    else
      context = "line #{line}: #{message}"

      case severity do
        :warning ->
          Warnings.build(:markdown_parse_error, %{context: context})

        :error ->
          Warnings.build(:markdown_parse_error, %{context: context})

        _ ->
          Warnings.build(:markdown_parse_error, %{context: context})
      end
    end
  end
end