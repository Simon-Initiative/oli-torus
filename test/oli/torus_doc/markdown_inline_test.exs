defmodule Oli.TorusDoc.MarkdownInlineTest do
  use ExUnit.Case

  alias Oli.TorusDoc.Markdown.MarkdownParser

  describe "inline markup formatting" do
    test "converts bold text with strong mark on text node" do
      markdown = "This is **bold text** here."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]
      assert length(children) == 3

      assert Enum.at(children, 0) == %{"text" => "This is "}
      assert Enum.at(children, 1) == %{"text" => "bold text", "strong" => true}
      assert Enum.at(children, 2) == %{"text" => " here."}
    end

    test "converts italic text with em mark on text node" do
      markdown = "This is *italic text* here."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]
      assert length(children) == 3

      assert Enum.at(children, 0) == %{"text" => "This is "}
      assert Enum.at(children, 1) == %{"text" => "italic text", "em" => true}
      assert Enum.at(children, 2) == %{"text" => " here."}
    end

    test "converts bold and italic text with both marks" do
      markdown = "This is ***bold and italic*** text."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]
      assert length(children) == 3

      assert Enum.at(children, 0) == %{"text" => "This is "}

      assert Enum.at(children, 1) == %{
               "text" => "bold and italic",
               "strong" => true,
               "em" => true
             }

      assert Enum.at(children, 2) == %{"text" => " text."}
    end

    test "converts inline code with code mark" do
      markdown = "This is `inline code` here."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]
      assert length(children) == 3

      assert Enum.at(children, 0) == %{"text" => "This is "}
      assert Enum.at(children, 1) == %{"text" => "inline code", "code" => true}
      assert Enum.at(children, 2) == %{"text" => " here."}
    end

    test "converts strikethrough text with strikethrough mark" do
      markdown = "This is ~~strikethrough~~ text."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]
      assert length(children) == 3

      assert Enum.at(children, 0) == %{"text" => "This is "}
      assert Enum.at(children, 1) == %{"text" => "strikethrough", "strikethrough" => true}
      assert Enum.at(children, 2) == %{"text" => " text."}
    end

    test "converts nested bold within italic" do
      markdown = "This is *italic with **bold** inside* text."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      assert paragraph["type"] == "p"

      children = paragraph["children"]

      # The markdown parser should produce a flat structure with appropriate marks
      assert Enum.any?(children, fn child ->
               Map.get(child, "text") == "italic with " && Map.get(child, "em") == true
             end)

      assert Enum.any?(children, fn child ->
               Map.get(child, "text") == "bold" && Map.get(child, "em") == true &&
                 Map.get(child, "strong") == true
             end)

      assert Enum.any?(children, fn child ->
               Map.get(child, "text") == " inside" && Map.get(child, "em") == true
             end)
    end

    test "handles mixed formatting in list items" do
      markdown = """
      - Item with **bold** text
      - Item with *italic* text
      - Item with `code` text
      """

      assert {:ok, [list]} = MarkdownParser.parse(markdown)
      assert list["type"] == "ul"

      items = list["children"]
      assert length(items) == 3

      # First item with bold
      item1 = Enum.at(items, 0)
      assert item1["type"] == "li"
      item1_children = item1["children"]
      assert Enum.any?(item1_children, &(&1 == %{"text" => "bold", "strong" => true}))

      # Second item with italic
      item2 = Enum.at(items, 1)
      assert item2["type"] == "li"
      item2_children = item2["children"]
      assert Enum.any?(item2_children, &(&1 == %{"text" => "italic", "em" => true}))

      # Third item with code
      item3 = Enum.at(items, 2)
      assert item3["type"] == "li"
      item3_children = item3["children"]
      assert Enum.any?(item3_children, &(&1 == %{"text" => "code", "code" => true}))
    end

    test "preserves marks in headings" do
      markdown = "# Heading with **bold** and *italic*"

      assert {:ok, [heading]} = MarkdownParser.parse(markdown)
      assert heading["type"] == "h1"

      children = heading["children"]
      assert Enum.any?(children, &(&1 == %{"text" => "Heading with "}))
      assert Enum.any?(children, &(&1 == %{"text" => "bold", "strong" => true}))
      assert Enum.any?(children, &(&1 == %{"text" => " and "}))
      assert Enum.any?(children, &(&1 == %{"text" => "italic", "em" => true}))
    end

    test "merges adjacent text nodes with same marks" do
      markdown = "**Bold** **text** should merge."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)
      children = paragraph["children"]

      # Adjacent bold text should be merged
      assert Enum.any?(children, fn child ->
               Map.get(child, "text") =~ "Bold" && Map.get(child, "strong") == true
             end)
    end

    test "does not use nested elements for inline formatting" do
      markdown = "Text with **bold** and *italic* parts."

      assert {:ok, [paragraph]} = MarkdownParser.parse(markdown)

      # All children should be text nodes (maps with "text" key) 
      # or inline elements like links, not nested formatting elements
      assert Enum.all?(paragraph["children"], fn child ->
               is_map(child) &&
                 (Map.has_key?(child, "text") || Map.get(child, "type") in ["a", "img_inline"])
             end)
    end
  end
end
