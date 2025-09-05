defmodule Oli.TorusDoc.Markdown.InlineParser do
  @moduledoc """
  Handles inline element parsing for TMD, including text formatting,
  links, images, and inline math.
  """

  @doc """
  Transforms an inline element from Earmark AST to Torus JSON.
  """
  def transform(element, directive_map \\ %{})

  # Text nodes
  def transform(text, _) when is_binary(text) do
    text
    |> process_inline_math()
    |> Enum.flat_map(&process_inline_directives/1)
  end

  # Strong emphasis
  def transform({"strong", _, children, _meta}, directive_map) do
    children
    |> Enum.flat_map(&transform(&1, directive_map))
    |> apply_mark("strong")
  end

  # Emphasis
  def transform({"em", _, children, _meta}, directive_map) do
    children
    |> Enum.flat_map(&transform(&1, directive_map))
    |> apply_mark("em")
  end

  # Code
  def transform({"code", _, [text], _meta}, _) when is_binary(text) do
    [%{"text" => text, "code" => true}]
  end

  # Links
  def transform({"a", [{"href", href} | _], children, _meta}, directive_map) do
    link_children = children |> Enum.flat_map(&transform(&1, directive_map))

    [
      %{
        "type" => "a",
        "href" => href,
        "children" => link_children
      }
    ]
  end

  # Images
  def transform({"img", attrs, _, _meta}, _) do
    attrs_map = attrs |> Enum.into(%{})

    img = %{
      "type" => "img_inline",
      "src" => attrs_map["src"] || ""
    }

    img
    |> maybe_add_attr("alt", attrs_map["alt"])
    |> maybe_add_attr("width", parse_dimension(attrs_map["width"]))
    |> maybe_add_attr("height", parse_dimension(attrs_map["height"]))
    |> List.wrap()
  end

  # Strikethrough (if GFM extension is enabled)
  def transform({"del", _, children, _meta}, directive_map) do
    children
    |> Enum.flat_map(&transform(&1, directive_map))
    |> apply_mark("strikethrough")
  end

  # Superscript (custom parsing needed)
  def transform({"sup", _, children, _meta}, directive_map) do
    children
    |> Enum.flat_map(&transform(&1, directive_map))
    |> apply_mark("sup")
  end

  # Subscript (custom parsing needed)
  def transform({"sub", _, children, _meta}, directive_map) do
    children
    |> Enum.flat_map(&transform(&1, directive_map))
    |> apply_mark("sub")
  end

  # Line breaks
  def transform({"br", _, _, _meta}, _) do
    [%{"text" => "\n"}]
  end

  # Directive placeholders
  def transform({"directive", %{"id" => id}}, directive_map) do
    case Map.get(directive_map, id) do
      nil -> []
      directive -> [directive]
    end
  end

  # Unknown elements - try to extract text
  def transform({_, _, children, _meta}, directive_map) when is_list(children) do
    Enum.flat_map(children, &transform(&1, directive_map))
  end

  def transform(_, _), do: []

  @doc """
  Process inline math delimiters in text.
  Converts placeholders back to inline formula elements.
  """
  def process_inline_math(text) do
    # Pattern for inline math placeholder
    inline_math_regex = ~r/INLINE_MATH_START_(.+?)_INLINE_MATH_END/

    case Regex.split(inline_math_regex, text, include_captures: true) do
      [^text] ->
        # No math found, return plain text
        [%{"text" => text}]

      parts ->
        # Process alternating text and math
        parts
        |> process_math_parts([])
    end
  end

  defp process_math_parts([], acc), do: Enum.reverse(acc)

  defp process_math_parts([text | rest], acc) when rest == [] do
    # Last part, just text
    if text == "" do
      Enum.reverse(acc)
    else
      Enum.reverse([%{"text" => text} | acc])
    end
  end

  defp process_math_parts([text, math_placeholder | rest], acc) do
    text_node = if text == "", do: nil, else: %{"text" => text}

    # Check if this is actually a math placeholder
    math_node =
      if String.starts_with?(math_placeholder, "INLINE_MATH_START_") do
        # Extract math content from placeholder
        encoded =
          math_placeholder
          |> String.trim_leading("INLINE_MATH_START_")
          |> String.trim_trailing("_INLINE_MATH_END")

        # Decode the base64 content
        math_content =
          case Base.decode64(encoded, padding: false) do
            {:ok, decoded} -> decoded
            # Fallback if decoding fails
            :error -> encoded
          end

        %{
          "type" => "formula_inline",
          "subtype" => "latex",
          "src" => math_content
        }
      else
        # Not a math placeholder, treat as text
        %{"text" => math_placeholder}
      end

    new_acc =
      if text_node do
        [math_node, text_node | acc]
      else
        [math_node | acc]
      end

    process_math_parts(rest, new_acc)
  end

  @doc """
  Process inline directive placeholders in text nodes or elements.
  """
  def process_inline_directives(%{"text" => text} = node) do
    # Pattern for inline directive placeholder - attrs part is always present even if empty
    inline_dir_regex = ~r/INLINE_DIR_START_([^_]+)_([^_]+)_([^_]*)_INLINE_DIR_END/

    case Regex.split(inline_dir_regex, text, include_captures: true) do
      [^text] ->
        # No directive found, return as is
        [node]

      parts ->
        # Process parts that might contain directives
        parts
        |> process_directive_parts([])
        |> Enum.map(fn
          # Apply existing marks to text nodes
          %{"text" => _} = text_node ->
            Map.merge(text_node, Map.drop(node, ["text"]))

          other ->
            other
        end)
    end
  end

  def process_inline_directives(element), do: [element]

  defp process_directive_parts([], acc), do: Enum.reverse(acc)

  defp process_directive_parts([text | rest], acc) when rest == [] do
    if text == "" do
      Enum.reverse(acc)
    else
      Enum.reverse([%{"text" => text} | acc])
    end
  end

  defp process_directive_parts([text, directive_placeholder | rest], acc) do
    text_node = if text == "", do: nil, else: %{"text" => text}

    directive_node =
      if String.starts_with?(directive_placeholder, "INLINE_DIR_START_") do
        # Extract directive components
        parts =
          directive_placeholder
          |> String.trim_leading("INLINE_DIR_START_")
          |> String.trim_trailing("_INLINE_DIR_END")
          |> String.split("_")

        case parts do
          [encoded_name, encoded_text, encoded_attrs] ->
            name = decode_base64(encoded_name)
            text_content = decode_base64(encoded_text)
            attrs = decode_base64(encoded_attrs)

            build_inline_directive(name, text_content, attrs)

          _ ->
            # Malformed directive, treat as text
            %{"text" => directive_placeholder}
        end
      else
        %{"text" => directive_placeholder}
      end

    new_acc =
      if text_node do
        [directive_node, text_node | acc]
      else
        [directive_node | acc]
      end

    process_directive_parts(rest, new_acc)
  end

  defp decode_base64(encoded) do
    case Base.decode64(encoded, padding: false) do
      {:ok, decoded} -> decoded
      :error -> ""
    end
  end

  defp build_inline_directive("term", text, attrs) do
    # Parse attributes
    attrs_map = parse_inline_attrs(attrs)

    # For term directive, we can use callout_inline type as a semantic marker
    # Or just use a span with attributes
    base = %{
      "type" => "callout_inline",
      "children" => [%{"text" => text}]
    }

    # Add id if present
    case attrs_map["id"] do
      nil -> base
      id -> Map.put(base, "id", id)
    end
  end

  defp build_inline_directive(_name, text, _attrs) do
    # Unknown inline directive, just return text
    %{"text" => text}
  end

  defp parse_inline_attrs(""), do: %{}

  defp parse_inline_attrs(attrs_str) do
    # Simple key="value" parser
    ~r/(\w+)\s*=\s*"([^"]*)"/
    |> Regex.scan(attrs_str)
    |> Enum.map(fn [_, key, value] -> {key, value} end)
    |> Enum.into(%{})
  end

  @doc """
  Apply a text mark (bold, italic, etc.) to a list of text nodes.
  """
  def apply_mark(nodes, mark) when is_list(nodes) do
    Enum.map(nodes, fn
      %{"text" => _} = text_node ->
        Map.put(text_node, mark, true)

      other ->
        other
    end)
  end

  @doc """
  Merge adjacent text nodes with the same marks.
  """
  def merge_adjacent_text(nodes) do
    nodes
    |> Enum.reduce([], fn
      %{"text" => _text} = node, [] ->
        [node]

      %{"text" => text} = node, [%{"text" => prev_text} = prev | rest] ->
        if same_marks?(node, prev) do
          merged = Map.put(prev, "text", prev_text <> text)
          [merged | rest]
        else
          [node, prev | rest]
        end

      node, acc ->
        [node | acc]
    end)
    |> Enum.reverse()
  end

  defp same_marks?(node1, node2) do
    marks = ["strong", "em", "code", "strikethrough", "sup", "sub", "underline"]

    Enum.all?(marks, fn mark ->
      Map.get(node1, mark, false) == Map.get(node2, mark, false)
    end)
  end

  defp maybe_add_attr(map, _key, nil), do: map
  defp maybe_add_attr(map, _key, ""), do: map
  defp maybe_add_attr(map, key, value), do: Map.put(map, key, value)

  defp parse_dimension(nil), do: nil

  defp parse_dimension(value) when is_binary(value) do
    case Integer.parse(value) do
      {num, _} -> num
      _ -> value
    end
  end

  defp parse_dimension(value), do: value
end
