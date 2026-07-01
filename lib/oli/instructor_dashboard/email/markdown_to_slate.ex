defmodule Oli.InstructorDashboard.Email.MarkdownToSlate do
  @moduledoc """
  Converts an AI-generated markdown email body into Slate nodes for the
  draft editor.

  The draft `RichTextEditor` is restricted to inline content + links (no block
  elements). This reuses `Oli.TorusDoc.Markdown.MarkdownParser` for robust inline
  and link parsing, then flattens block-level structures (headings, lists,
  blockquotes, code) into paragraphs so the result fits the editor.
  """

  alias Oli.TorusDoc.Markdown.MarkdownParser
  alias Oli.InstructorDashboard.Email.LinkValidator

  @empty_text [%{"text" => ""}]
  @empty [%{"type" => "p", "children" => @empty_text}]

  @spec to_slate(String.t() | nil) :: [map()]
  def to_slate(markdown) when is_binary(markdown),
    do: markdown |> MarkdownParser.parse() |> from_parse(markdown)

  def to_slate(_), do: @empty

  defp from_parse({:ok, nodes}, _markdown),
    do: nodes |> Enum.flat_map(&flatten/1) |> non_empty()

  # Fall back to treating the whole string as a plain-text paragraph.
  defp from_parse({:error, _reason}, markdown),
    do: [%{"type" => "p", "children" => [%{"text" => markdown}]}]

  defp non_empty([]), do: @empty
  defp non_empty(nodes), do: nodes

  # Paragraphs keep their (inline) children.
  defp flatten(%{"type" => "p", "children" => children}),
    do: [%{"type" => "p", "children" => inline_children(children)}]

  # Headings and list items collapse to paragraphs; their children are inline.
  defp flatten(%{"type" => type, "children" => children})
       when type in ~w(h1 h2 h3 h4 h5 h6 li),
       do: [%{"type" => "p", "children" => inline_children(children)}]

  # Containers recurse into their children.
  defp flatten(%{"type" => type, "children" => children})
       when type in ~w(ul ol blockquote),
       do: Enum.flat_map(children, &flatten/1)

  # Code blocks become a plain-text paragraph of their code.
  defp flatten(%{"type" => "code", "code" => code}) when is_binary(code),
    do: [%{"type" => "p", "children" => [%{"text" => code}]}]

  # Anything else (tables, unknown) is dropped — it can't be represented inline.
  defp flatten(_), do: []

  # Keep only inline text + link nodes; links keep their inline children.
  defp inline_children(children) when is_list(children),
    do: children |> Enum.flat_map(&to_inline/1) |> non_empty_text()

  defp inline_children(_), do: @empty_text

  defp to_inline(%{"type" => "a", "href" => href, "children" => link_children}) do
    if LinkValidator.valid_internal_path?(href) do
      [%{"type" => "a", "href" => href, "children" => inline_children(link_children)}]
    else
      # Drop an unsafe/invalid link target, keeping its visible text.
      inline_children(link_children)
    end
  end

  defp to_inline(%{"type" => "a", "children" => link_children}),
    do: inline_children(link_children)

  defp to_inline(%{"text" => _} = text_node), do: [text_node]
  defp to_inline(_), do: []

  defp non_empty_text([]), do: @empty_text
  defp non_empty_text(nodes), do: nodes
end
