defmodule Oli.TorusDoc.Markdown.MarkdownParser do
  @moduledoc """
  TorusDoc Markdown (TMD) parser that converts markdown to Torus JSON content elements.

  Implements the TMD specification for parsing markdown with custom directives
  into the Torus content element schema.
  """

  alias Oli.TorusDoc.Markdown.DirectiveParser
  alias Oli.TorusDoc.Markdown.InlineParser
  alias Oli.TorusDoc.Markdown.BlockParser
  alias Oli.TorusDoc.Markdown.TableParser

  @doc """
  Parses a TorusDoc Markdown string into Torus JSON content elements.

  ## Examples

      iex> Oli.TorusDoc.MarkdownParser.parse("# Hello\n\nThis is a paragraph.")
      {:ok, [
        %{"type" => "h1", "children" => [%{"text" => "Hello"}]},
        %{"type" => "p", "children" => [%{"text" => "This is a paragraph."}]}
      ]}
  """
  @spec parse(String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def parse(markdown) when is_binary(markdown) do
    markdown
    |> preprocess_inline_math()
    |> preprocess_inline_directives()
    |> BlockParser.preprocess_math()
    |> preprocess_directives()
    |> parse_with_earmark()
    |> transform_to_torus_json()
  end

  # Preprocess inline math to preserve it from Earmark processing
  defp preprocess_inline_math(markdown) do
    # Replace \( ... \) with a placeholder that Earmark won't modify
    inline_math_regex = ~r/\\\((.+?)\\\)/

    Regex.replace(inline_math_regex, markdown, fn _, math_content ->
      # Use a placeholder that won't be interpreted as markdown
      # Using HTML comment style to prevent markdown interpretation
      encoded = Base.encode64(math_content, padding: false)
      "INLINE_MATH_START_#{encoded}_INLINE_MATH_END"
    end)
  end

  # Preprocess inline directives like :term[text]{attrs}
  defp preprocess_inline_directives(markdown) do
    # Pattern for inline directives: :name[text]{attrs}
    inline_directive_regex = ~r/:(\w+)\[([^\]]*)\](?:\{([^}]*)\})?/

    Regex.replace(inline_directive_regex, markdown, fn _, name, text, attrs ->
      # Encode the directive components
      encoded_name = Base.encode64(name, padding: false)
      encoded_text = Base.encode64(text, padding: false)
      encoded_attrs = Base.encode64(attrs || "", padding: false)

      "INLINE_DIR_START_#{encoded_name}_#{encoded_text}_#{encoded_attrs}_INLINE_DIR_END"
    end)
  end

  # Preprocess custom directives before markdown parsing
  defp preprocess_directives(markdown) do
    DirectiveParser.extract_and_replace(markdown)
  end

  # Parse markdown using Earmark with GFM extensions
  defp parse_with_earmark({markdown, directive_map}) do
    options = %Earmark.Options{
      gfm: true,
      breaks: false,
      smartypants: false,
      pure_links: false
    }

    # Use the recommended Parser.as_ast function
    case Earmark.Parser.as_ast(markdown, options) do
      {:ok, ast, _messages} ->
        {:ok, ast, directive_map}

      {:error, ast, errors} ->
        {:error, format_errors(errors), ast, directive_map}
    end
  end

  defp format_errors(errors) do
    errors
    |> Enum.map(fn {_severity, line, message} ->
      "Line #{line}: #{message}"
    end)
    |> Enum.join("; ")
  end

  # Transform Earmark AST to Torus JSON
  defp transform_to_torus_json({:ok, ast, directive_map}) do
    elements = transform_elements(ast, directive_map)
    {:ok, elements}
  end

  defp transform_to_torus_json({:error, reason, _ast, _directive_map}) do
    {:error, reason}
  end

  defp transform_elements(ast, directive_map) when is_list(ast) do
    Enum.flat_map(ast, &transform_element(&1, directive_map))
  end

  defp transform_element(element, directive_map) do
    case element do
      {"h1", _attrs, children, _meta} ->
        [%{"type" => "h1", "children" => transform_inline(children, directive_map)}]

      {"h2", _attrs, children, _meta} ->
        [%{"type" => "h2", "children" => transform_inline(children, directive_map)}]

      {"h3", _attrs, children, _meta} ->
        [%{"type" => "h3", "children" => transform_inline(children, directive_map)}]

      {"h4", _attrs, children, _meta} ->
        [%{"type" => "h4", "children" => transform_inline(children, directive_map)}]

      {"h5", _attrs, children, _meta} ->
        [%{"type" => "h5", "children" => transform_inline(children, directive_map)}]

      {"h6", _attrs, children, _meta} ->
        [%{"type" => "h6", "children" => transform_inline(children, directive_map)}]

      {"p", _attrs, children, _meta} ->
        # Check if this paragraph contains only a directive placeholder
        case children do
          [text] when is_binary(text) ->
            case extract_directive_id(text) do
              nil ->
                # Regular paragraph
                [%{"type" => "p", "children" => transform_inline(children, directive_map)}]

              id ->
                # Replace directive placeholder with actual directive content
                case Map.get(directive_map, id) do
                  nil -> []
                  directive -> [directive]
                end
            end

          _ ->
            # Regular paragraph with multiple children
            [%{"type" => "p", "children" => transform_inline(children, directive_map)}]
        end

      {"ul", _attrs, children, _meta} ->
        [%{"type" => "ul", "children" => transform_list_items(children, directive_map)}]

      {"ol", _attrs, children, _meta} ->
        [%{"type" => "ol", "children" => transform_list_items(children, directive_map)}]

      {"li", _attrs, children, _meta} ->
        [%{"type" => "li", "children" => transform_inline(children, directive_map)}]

      {"blockquote", _attrs, children, _meta} ->
        paragraphs = transform_elements(children, directive_map)
        [%{"type" => "blockquote", "children" => paragraphs}]

      {"pre", _, [{"code", [{"class", lang} | _], [code], _}], _meta} ->
        [BlockParser.transform_code_block(lang, code)]

      {"pre", _, [{"code", _, [code], _}], _meta} ->
        [BlockParser.transform_code_block("text", code)]

      {"table", _attrs, children, _meta} ->
        [TableParser.parse_table(children, directive_map)]

      {"hr", _, _, _} ->
        # Horizontal rules are not in the schema, skip them
        []

      text when is_binary(text) ->
        # Plain text at block level gets wrapped in paragraph
        if String.trim(text) == "" do
          []
        else
          [%{"type" => "p", "children" => [%{"text" => text}]}]
        end

      _ ->
        # Unknown element, skip
        []
    end
  end

  defp transform_list_items(items, directive_map) do
    Enum.flat_map(items, fn
      {"li", _attrs, children, _meta} ->
        # Check if children contain nested lists
        {inline_content, nested_lists} = partition_list_content(children)

        li_children = transform_inline(inline_content, directive_map)

        base_item = %{"type" => "li", "children" => li_children}

        # Add nested lists as siblings after the list item
        [base_item | transform_elements(nested_lists, directive_map)]

      other ->
        transform_element(other, directive_map)
    end)
  end

  defp partition_list_content(children) do
    Enum.split_with(children, fn
      {"ul", _, _, _} -> false
      {"ol", _, _, _} -> false
      _ -> true
    end)
  end

  defp transform_inline(children, directive_map) when is_list(children) do
    children
    |> Enum.flat_map(&transform_inline_element(&1, directive_map))
    |> InlineParser.merge_adjacent_text()
  end

  defp transform_inline_element(element, directive_map) do
    InlineParser.transform(element, directive_map)
  end

  defp extract_directive_id(text) do
    case Regex.run(~r/TORUS_DIRECTIVE\[(directive_\d+)\]/, text) do
      [_, id] -> id
      _ -> nil
    end
  end
end
