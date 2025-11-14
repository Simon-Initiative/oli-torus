defmodule Oli.GoogleDocs.CustomElementsTest do
  use ExUnit.Case, async: true

  alias Oli.GoogleDocs.CustomElements
  alias Oli.GoogleDocs.CustomElements.{Dropdown, Mcq, YouTube}
  alias Oli.GoogleDocs.MarkdownParser
  alias Oli.GoogleDocs.MarkdownParser.CustomElement
  alias Oli.GoogleDocsImport.TestHelpers

  describe "resolve/2" do
    test "returns typed structs for recognised elements" do
      fixture = TestHelpers.load_fixture(:custom_elements)

      assert {:ok, parsed} =
               MarkdownParser.parse(fixture.body, metadata: fixture.metadata)

      assert {:ok, result} = CustomElements.resolve(parsed.custom_elements)

      assert result.order == Enum.map(parsed.custom_elements, & &1.id)
      assert result.warnings == []
      assert map_size(result.fallbacks) == 0

      youtube = Map.fetch!(result.elements, "custom-element-1")
      mcq = Map.fetch!(result.elements, "custom-element-2")

      assert %YouTube{
               source: "nioGsCPUjx8",
               video_id: "nioGsCPUjx8",
               caption: "A dog howling at a fire truck",
               embed_url: "https://www.youtube.com/embed/nioGsCPUjx8",
               watch_url: "https://www.youtube.com/watch?v=nioGsCPUjx8"
             } = youtube

      assert %Mcq{
               stem: "Which security model emphasises continuous verification?",
               correct_key: "choice2"
             } = mcq

      assert Enum.map(mcq.choices, & &1.id) == ["choice1", "choice2", "choice3"]

      assert Enum.map(mcq.choices, & &1.feedback_key) == [
               "feedback1",
               "feedback2",
               "feedback3"
             ]
    end

    test "falls back with warning for unknown element types" do
      custom = %CustomElement{
        id: "custom-element-99",
        element_type: "vimeo",
        data: %{"src" => "xyz"},
        raw_rows: [{"CustomElement", "vimeo"}],
        block_index: 10
      }

      assert {:ok, result} = CustomElements.resolve([custom])

      assert %{"custom-element-99" => %{reason: :unknown_type}} = result.fallbacks
      assert Enum.any?(result.warnings, &(&1.code == :custom_element_unknown))
      assert result.elements == %{}
    end

    test "returns fallback when required youtube fields are missing" do
      incomplete = %CustomElement{
        id: "custom-element-5",
        element_type: "youtube",
        data: %{"caption" => "Missing source"},
        raw_rows: [{"CustomElement", "youtube"}],
        block_index: 4
      }

      assert {:ok, result} = CustomElements.resolve([incomplete])

      assert %{"custom-element-5" => %{reason: :invalid}} = result.fallbacks
      assert Enum.any?(result.warnings, &(&1.code == :custom_element_invalid_shape))
    end

    test "resolves mcq custom element from markdown table" do
      markdown = """
      | CustomElement | MCQ |
      | --- | --- |
      | stem | Which of the following is an animal? |
      | choice1 | Dog |
      | feedback1 | Correct! A dog is an animal |
      | choice2 | Computer |
      | feedback2 | No, a computer is not an animal |
      | correct | choice1 |
      | hint1 | Which choice needs to be fed? |
      """

      assert {:ok, parsed} = MarkdownParser.parse(markdown)
      assert {:ok, result} = CustomElements.resolve(parsed.custom_elements)

      assert %Mcq{} = mcq = Map.fetch!(result.elements, hd(result.order))
      assert mcq.stem == "Which of the following is an animal?"
      assert Enum.map(mcq.choices, & &1.id) == ["choice1", "choice2"]
    end

    test "resolves dropdown custom element with per-input data" do
      markdown = """
      | CustomElement | Dropdown |
      | --- | --- |
      | stem | [dropdown1] and [dropdown2] are both animals. |
      | dropdown1-choice1 | Dog |
      | dropdown1-feedback1 | Correct! |
      | dropdown1-choice2 | Computer |
      | dropdown1-feedback2 | Incorrect. |
      | dropdown1-correct | choice1 |
      | dropdown1-hint1 | Think about pets. |
      | dropdown2-choice1 | Cat |
      | dropdown2-feedback1 | Correct! |
      | dropdown2-choice2 | Tree |
      | dropdown2-feedback2 | Incorrect. |
      | dropdown2-correct | choice1 |
      | dropdown2-hint1 | Which one needs food? |
      """

      assert {:ok, parsed} = MarkdownParser.parse(markdown)
      assert {:ok, resolved} = CustomElements.resolve(parsed.custom_elements)

      dropdown = Map.fetch!(resolved.elements, hd(resolved.order))
      assert %Dropdown{} = dropdown
      assert dropdown.inputs == ["dropdown1", "dropdown2"]
      assert dropdown.data_by_input["dropdown1"]["choice1"] == "Dog"
      assert dropdown.data_by_input["dropdown2"]["hint1"] == "Which one needs food?"
    end

    test "dropdown custom element with duplicate markers falls back" do
      markdown = """
      | CustomElement | Dropdown |
      | --- | --- |
      | stem | [dropdown1] and again [dropdown1]. |
      | dropdown1-choice1 | Dog |
      | dropdown1-choice2 | Cat |
      | dropdown1-correct | choice1 |
      """

      assert {:ok, parsed} = MarkdownParser.parse(markdown)
      assert {:ok, resolved} = CustomElements.resolve(parsed.custom_elements)

      assert %{"custom-element-1" => %{reason: :invalid}} = resolved.fallbacks
      assert Enum.any?(resolved.warnings, &(&1.code == :dropdown_duplicate_markers))
    end
  end
end
