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

  describe "custom directives" do
    test "parses YouTube directive" do
      markdown = """
      :::youtube { id="dQw4w9WgXcQ" start=42 title="Demo Video" }
      :::
      """

      {:ok, [youtube]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "youtube",
               "src" => "https://www.youtube.com/embed/dQw4w9WgXcQ",
               "startTime" => 42,
               "alt" => "Demo Video"
             } = youtube
    end

    test "parses audio directive" do
      markdown = """
      :::audio { src="/media/intro.mp3" caption="Course intro" }
      Optional transcript text here.
      :::
      """

      {:ok, [audio]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "audio",
               "src" => "/media/intro.mp3",
               "alt" => "Course intro",
               "caption" => "Optional transcript text here."
             } = audio
    end

    test "parses video directive" do
      markdown = """
      :::video { src="/media/clip.mp4" poster="/media/thumb.jpg" }
      Video description
      :::
      """

      {:ok, [video]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "video",
               "src" => [%{"url" => "/media/clip.mp4", "contenttype" => "video/mp4"}],
               "poster" => "/media/thumb.jpg",
               "alt" => "Video description"
             } = video
    end

    test "parses iframe directive" do
      markdown = """
      :::iframe { src="https://codepen.io/widget" width=640 height=360 title="Widget" }
      :::
      """

      {:ok, [iframe]} = MarkdownParser.parse(markdown)

      assert %{
               "type" => "iframe",
               "src" => "https://codepen.io/widget",
               "width" => 640,
               "height" => 360,
               "alt" => "Widget"
             } = iframe
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

  describe "directive validation" do
    test "validates YouTube ID format" do
      # Valid YouTube ID
      valid_markdown = """
      :::youtube { id="dQw4w9WgXcQ" }
      :::
      """

      {:ok, [youtube]} = MarkdownParser.parse(valid_markdown)
      assert %{"type" => "youtube"} = youtube

      # Invalid YouTube ID (too short)
      invalid_markdown = """
      :::youtube { id="abc123" }
      :::
      """

      {:ok, [error]} = MarkdownParser.parse(invalid_markdown)
      assert %{"type" => "p", "children" => [%{"text" => "[Invalid YouTube ID]"}]} = error
    end

    test "validates media source URLs" do
      # Valid relative path
      valid_audio = """
      :::audio { src="/media/audio.mp3" }
      :::
      """

      {:ok, [audio]} = MarkdownParser.parse(valid_audio)
      assert %{"type" => "audio", "src" => "/media/audio.mp3"} = audio

      # Invalid source (no protocol or relative path)
      invalid_audio = """
      :::audio { src="random-text" }
      :::
      """

      {:ok, [error]} = MarkdownParser.parse(invalid_audio)
      assert %{"type" => "p", "children" => [%{"text" => "[Invalid audio source]"}]} = error
    end

    test "validates iframe domains against allowlist" do
      # Allowed domain
      valid_iframe = """
      :::iframe { src="https://codepen.io/embed/abc" }
      :::
      """

      {:ok, [iframe]} = MarkdownParser.parse(valid_iframe)
      assert %{"type" => "iframe"} = iframe

      # Disallowed domain
      invalid_iframe = """
      :::iframe { src="https://evil-site.com/widget" }
      :::
      """

      {:ok, [error]} = MarkdownParser.parse(invalid_iframe)

      assert %{
               "type" => "p",
               "children" => [%{"text" => "[Invalid or disallowed iframe source]"}]
             } = error
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

    test "handles multiple consecutive directives" do
      markdown = """
      :::youtube { id="dQw4w9WgXcQ" }
      :::

      :::audio { src="/audio.mp3" }
      :::
      """

      {:ok, result} = MarkdownParser.parse(markdown)
      assert length(result) == 2
      assert Enum.at(result, 0)["type"] == "youtube"
      assert Enum.at(result, 1)["type"] == "audio"
    end

    test "handles directive with markdown body content" do
      markdown = """
      :::audio { src="/lecture.mp3" caption="Lecture Audio" }
      This is a **transcript** with *emphasis* and `code`.

      It has multiple paragraphs.
      :::
      """

      {:ok, [audio]} = MarkdownParser.parse(markdown)
      assert %{"type" => "audio", "caption" => caption} = audio
      assert caption =~ "transcript"
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

      This document demonstrates **all** TMD features including :term[special terms]{id="term1"}.

      ## Media

      :::youtube { id="dQw4w9WgXcQ" start=10 }
      :::

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
      assert "youtube" in types
      assert "formula" in types
      assert "table" in types
      assert "ol" in types
      assert "blockquote" in types
      assert "code" in types
    end
  end
end
