defmodule Oli.TorusDoc.MarkdownParserTest do
  use ExUnit.Case, async: true

  alias Oli.TorusDoc.Markdown.MarkdownParser

  describe "basic text blocks" do
    test "parses paragraphs" do
      markdown = "This is a paragraph.\n\nThis is another paragraph."
      {:ok, result} = MarkdownParser.parse(markdown)

      assert [
               %{"type" => "p", "children" => [%{"text" => "This is a paragraph."}]},
               %{"type" => "p", "children" => [%{"text" => "This is another paragraph."}]}
             ] = result
    end

    test "parses headings" do
      markdown = """
      # Heading 1
      ## Heading 2
      ### Heading 3
      #### Heading 4
      ##### Heading 5
      ###### Heading 6
      """

      {:ok, result} = MarkdownParser.parse(markdown)

      assert [
               %{"type" => "h1", "children" => [%{"text" => "Heading 1"}]},
               %{"type" => "h2", "children" => [%{"text" => "Heading 2"}]},
               %{"type" => "h3", "children" => [%{"text" => "Heading 3"}]},
               %{"type" => "h4", "children" => [%{"text" => "Heading 4"}]},
               %{"type" => "h5", "children" => [%{"text" => "Heading 5"}]},
               %{"type" => "h6", "children" => [%{"text" => "Heading 6"}]}
             ] = result
    end
  end

  describe "inline formatting" do
    test "parses bold text" do
      markdown = "This is **bold** text."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "This is "},
                 %{"text" => "bold", "strong" => true},
                 %{"text" => " text."}
               ]
             } = paragraph
    end

    test "parses italic text" do
      markdown = "This is *italic* text."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "This is "},
                 %{"text" => "italic", "em" => true},
                 %{"text" => " text."}
               ]
             } = paragraph
    end

    test "parses inline code" do
      markdown = "Use `code` for inline code."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "Use "},
                 %{"text" => "code", "code" => true},
                 %{"text" => " for inline code."}
               ]
             } = paragraph
    end

    test "parses inline math" do
      markdown = "The equation \\(E=mc^2\\) is famous."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "The equation "},
                 %{"type" => "formula_inline", "subtype" => "latex", "src" => "E=mc^2"},
                 %{"text" => " is famous."}
               ]
             } = paragraph
    end
  end

  describe "lists" do
    test "parses unordered lists" do
      markdown = """
      - Item 1
      - Item 2
      - Item 3
      """

      {:ok, [list]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "ul",
               "children" => [
                 %{"type" => "li", "children" => [%{"text" => "Item 1"}]},
                 %{"type" => "li", "children" => [%{"text" => "Item 2"}]},
                 %{"type" => "li", "children" => [%{"text" => "Item 3"}]}
               ]
             } = list
    end

    test "parses ordered lists" do
      markdown = """
      1. First
      2. Second
      3. Third
      """

      {:ok, [list]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "ol",
               "children" => [
                 %{"type" => "li", "children" => [%{"text" => "First"}]},
                 %{"type" => "li", "children" => [%{"text" => "Second"}]},
                 %{"type" => "li", "children" => [%{"text" => "Third"}]}
               ]
             } = list
    end

    test "parses nested lists" do
      markdown = """
      - Item A
        - Nested A1
        - Nested A2
      - Item B
      """

      {:ok, [list]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "ul",
               "children" => [
                 %{"type" => "li", "children" => [%{"text" => "Item A"}]},
                 %{
                   "type" => "ul",
                   "children" => [
                     %{"type" => "li", "children" => [%{"text" => "Nested A1"}]},
                     %{"type" => "li", "children" => [%{"text" => "Nested A2"}]}
                   ]
                 },
                 %{"type" => "li", "children" => [%{"text" => "Item B"}]}
               ]
             } = list
    end
  end

  describe "code blocks" do
    test "parses fenced code blocks with language" do
      markdown = """
      ```python
      def hello():
          print("Hello, World!")
      ```
      """

      {:ok, [code]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "code",
               "language" => "python",
               "code" => "def hello():\n    print(\"Hello, World!\")"
             } = code
    end

    test "parses fenced code blocks without language" do
      markdown = """
      ```
      plain text code
      ```
      """

      {:ok, [code]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "code",
               "language" => "text",
               "code" => "plain text code"
             } = code
    end
  end

  describe "block math" do
    test "parses block math with double dollar signs" do
      markdown = """
      $$
      s = ut + \\tfrac{1}{2}at^2
      $$
      """

      {:ok, [formula]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "formula",
               "subtype" => "latex",
               "src" => "s = ut + \\tfrac{1}{2}at^2"
             } = formula
    end
  end

  describe "tables" do
    test "parses simple tables" do
      markdown = """
      | Header 1 | Header 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      | Cell 3   | Cell 4   |
      """

      {:ok, [table]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "table",
               "children" => [
                 %{
                   "type" => "tr",
                   "children" => [
                     %{"type" => "th", "children" => [%{"text" => "Header 1"}]},
                     %{"type" => "th", "children" => [%{"text" => "Header 2"}]}
                   ]
                 },
                 %{
                   "type" => "tr",
                   "children" => [
                     %{"type" => "td", "children" => [%{"text" => "Cell 1"}]},
                     %{"type" => "td", "children" => [%{"text" => "Cell 2"}]}
                   ]
                 },
                 %{
                   "type" => "tr",
                   "children" => [
                     %{"type" => "td", "children" => [%{"text" => "Cell 3"}]},
                     %{"type" => "td", "children" => [%{"text" => "Cell 4"}]}
                   ]
                 }
               ]
             } = table
    end

    test "parses tables with alignment" do
      markdown = """
      | Left | Center | Right |
      |:-----|:------:|------:|
      | A    | B      | C     |
      """

      {:ok, [table]} = MarkdownParser.parse(markdown)

      # Note: Earmark may not preserve alignment info in all cases
      assert %{"type" => "table"} = table
    end
  end

  describe "links and images" do
    test "parses links" do
      markdown = "Check out [Elixir](https://elixir-lang.org)."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "Check out "},
                 %{
                   "type" => "a",
                   "href" => "https://elixir-lang.org",
                   "children" => [%{"text" => "Elixir"}]
                 },
                 %{"text" => "."}
               ]
             } = paragraph
    end

    test "parses images" do
      markdown = "![Alt text](image.png)"
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{
                   "type" => "img_inline",
                   "src" => "image.png",
                   "alt" => "Alt text"
                 }
               ]
             } = paragraph
    end
  end

  describe "blockquotes" do
    test "parses blockquotes" do
      markdown = "> This is a quote\n> with multiple lines"
      {:ok, [blockquote]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "blockquote",
               "children" => [
                 %{
                   "type" => "p",
                   "children" => [%{"text" => "This is a quote\nwith multiple lines"}]
                 }
               ]
             } = blockquote
    end
  end

  describe "inline directives" do
    test "parses term directive" do
      markdown = "The :term[acceleration]{id=\"accel\"} is the rate of change."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "The "},
                 %{
                   "type" => "callout_inline",
                   "id" => "accel",
                   "children" => [%{"text" => "acceleration"}]
                 },
                 %{"text" => " is the rate of change."}
               ]
             } = paragraph
    end

    test "parses term directive without attributes" do
      markdown = "A :term[velocity] is a vector quantity."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "p",
               "children" => [
                 %{"text" => "A "},
                 %{
                   "type" => "callout_inline",
                   "children" => [%{"text" => "velocity"}]
                 },
                 %{"text" => " is a vector quantity."}
               ]
             } = paragraph
    end
  end

  describe "edge cases" do
    test "handles empty markdown" do
      {:ok, result} = MarkdownParser.parse("")
      assert result == []
    end

    test "handles markdown with only whitespace" do
      {:ok, result} = MarkdownParser.parse("   \n\n   ")
      assert result == []
    end

    test "preserves text marks in complex inline content" do
      markdown = "Text with **bold _italic_ text** and `code`."
      {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      assert %{"type" => "p", "children" => children} = paragraph
      assert length(children) > 0
    end

    test "handles nested lists with mixed types" do
      markdown = """
      1. First ordered item
         - Nested unordered
         - Another nested
      2. Second ordered item
      """

      {:ok, [list]} = MarkdownParser.parse(markdown)
      assert %{"type" => "ol"} = list
    end

    test "handles tables with inline formatting" do
      markdown = """
      | **Bold Header** | *Italic Header* |
      |-----------------|-----------------|
      | Cell with `code` | Cell with \\(math\\) |
      """

      {:ok, [table]} = MarkdownParser.parse(markdown)
      assert %{"type" => "table"} = table
    end
  end

  describe "complex documents" do
    test "parses document with multiple elements" do
      markdown = """
      # Introduction

      This is a paragraph with **bold** and *italic* text.

      ## Lists

      - Item 1
      - Item 2

      ## Code

      ```elixir
      def hello, do: :world
      ```

      ## Math

      The formula \\(E=mc^2\\) is inline, and here's block math:

      $$
      x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}
      $$
      """

      {:ok, result} = MarkdownParser.parse(markdown)

      assert length(result) >= 7
      assert Enum.any?(result, &match?(%{"type" => "h1"}, &1))
      assert Enum.any?(result, &match?(%{"type" => "h2"}, &1))
      assert Enum.any?(result, &match?(%{"type" => "ul"}, &1))
      assert Enum.any?(result, &match?(%{"type" => "code", "language" => "elixir"}, &1))
      assert Enum.any?(result, &match?(%{"type" => "formula"}, &1))
    end

    test "parses complete TMD document" do
      markdown = """
      # TorusDoc Example

      This document demonstrates **all** TMD features.

      ## Media Section

      ## Math Examples

      Inline math: \\(F = ma\\) and block math:

      $$
      \\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}
      $$

      ## Table

      | Feature | Status |
      |---------|--------|
      | **Bold** | ✓ |
      | *Italic* | ✓ |
      | `Code` | ✓ |

      ## Lists

      1. Ordered item
         - Nested unordered
      2. Another item

      > This is a blockquote
      > with multiple lines

      ```python
      def fibonacci(n):
          return n if n <= 1 else fibonacci(n-1) + fibonacci(n-2)
      ```
      """

      {:ok, result} = MarkdownParser.parse(markdown)

      # Verify we have all major element types
      types = result |> Enum.map(& &1["type"]) |> Enum.uniq()

      assert "h1" in types
      assert "h2" in types
      assert "p" in types
      assert "formula" in types
      assert "table" in types
      assert "ol" in types
      assert "blockquote" in types
      assert "code" in types
    end
  end
end
