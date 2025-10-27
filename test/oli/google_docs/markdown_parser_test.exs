defmodule Oli.GoogleDocs.MarkdownParserTest do
  use ExUnit.Case, async: true

  alias Oli.GoogleDocs.MarkdownParser
  alias Oli.GoogleDocs.MarkdownParser.{CustomElement, MediaReference}
  alias Oli.GoogleDocsImport.TestHelpers

  describe "parse/2 baseline content" do
    test "emits heading, paragraph, list, and blockquote blocks with inline marks preserved" do
      fixture = TestHelpers.load_fixture(:baseline)

      assert {:ok, result} =
               MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      assert result.title ==
               (fixture.metadata["title"] || fixture.metadata[:title])

      block_types = Enum.map(result.blocks, & &1.type)

      assert block_types == [
               :heading,
               :paragraph,
               :heading,
               :paragraph,
               :heading,
               :unordered_list,
               :ordered_list,
               :blockquote,
               :paragraph
             ]

      paragraph_with_marks =
        Enum.find(result.blocks, fn
          %{type: :paragraph, inlines: inlines} ->
            has_mark?(inlines, [:bold, :strong]) &&
              has_mark?(inlines, [:italic, :em])

          _ ->
            false
        end)

      assert paragraph_with_marks

      final_paragraph = List.last(result.blocks)
      assert Enum.any?(final_paragraph.inlines, &(:code in &1.marks))
    end
  end

  describe "parse/2 custom elements" do
    test "detects youtube and mcq tables and emits placeholders" do
      fixture = TestHelpers.load_fixture(:custom_elements)

      assert {:ok, result} =
               MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      assert Enum.count(result.custom_elements) == 2

      assert Enum.map(result.custom_elements, & &1.element_type) == ["youtube", "mcq"]

      assert Enum.all?(result.custom_elements, fn %CustomElement{data: data} ->
               map_size(data) >= 2
             end)

      placeholders =
        result.blocks
        |> Enum.filter(&(&1.type == :custom_element_placeholder))

      assert Enum.count(placeholders) == 2
      assert Enum.map(placeholders, & &1.element_type) == ["youtube", "mcq"]
    end
  end

  describe "parse/2 media references" do
    test "collects embedded data URL images with media references" do
      fixture = TestHelpers.load_fixture(:media)

      assert {:ok, result} =
               MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      image_blocks =
        result.blocks
        |> Enum.filter(&(&1.type == :image))

      assert Enum.count(image_blocks) == 2

      assert Enum.count(result.media) == 2
      assert Enum.all?(result.media, &match?(%MediaReference{origin: :data_url}, &1))

      assert result.media |> Enum.map(& &1.data) |> Enum.uniq() |> length() == 1
    end
  end

  describe "parse/2 invalid custom element tables" do
    test "falls back to table block and adds warning" do
      markdown = """
      | CustomElement | youtube |
      | --- | --- |
      | src | |
      """

      assert {:ok, result} = MarkdownParser.parse(markdown)

      assert Enum.any?(result.blocks, &(&1.type == :table))
      assert result.custom_elements == []
      assert Enum.any?(result.warnings, &(&1.code == :custom_element_invalid_shape))
    end
  end

  describe "parse/2 block math" do
    test "converts $$ delimiters into formula blocks" do
      markdown = """
      $$ \\\frac{2}{3} $$
      """

      assert {:ok, result} = MarkdownParser.parse(markdown)

      [%{type: :formula}] = result.blocks
    end
  end

  defp has_mark?(inlines, allowed_marks) do
    Enum.any?(inlines, fn inline ->
      inline.marks
      |> List.wrap()
      |> Enum.any?(&(&1 in allowed_marks))
    end)
  end
end
