defmodule Oli.TorusDoc.MCQInlineMarkupTest do
  use ExUnit.Case

  alias Oli.TorusDoc.ActivityConverter

  describe "MCQ with inline markup" do
    test "preserves inline markup in stem" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "What is the **derivative** of *f(x) = x²*?"
      choices:
        - id: "A"
          body_md: "2x"
          score: 1
        - id: "B"
          body_md: "x"
          score: 0
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      stem_content = json["stem"]["content"] |> List.first()
      assert stem_content["type"] == "p"

      children = stem_content["children"]
      assert Enum.any?(children, &(&1 == %{"text" => "What is the "}))
      assert Enum.any?(children, &(&1 == %{"text" => "derivative", "strong" => true}))
      assert Enum.any?(children, &(&1 == %{"text" => " of "}))
      assert Enum.any?(children, &(&1 == %{"text" => "f(x) = x²", "em" => true}))
      assert Enum.any?(children, &(&1 == %{"text" => "?"}))
    end

    test "preserves inline markup in choices" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Select the correct answer:"
      choices:
        - id: "A"
          body_md: "The **correct** answer"
          score: 1
        - id: "B"
          body_md: "An *incorrect* answer"
          score: 0
        - id: "C"
          body_md: "Another `wrong` answer"
          score: 0
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      # Check choice A has bold
      choice_a = Enum.find(json["choices"], &(&1["id"] == "A"))
      choice_a_content = choice_a["content"] |> List.first()
      assert choice_a_content["type"] == "p"
      children_a = choice_a_content["children"]
      assert Enum.any?(children_a, &(&1 == %{"text" => "The "}))
      assert Enum.any?(children_a, &(&1 == %{"text" => "correct", "strong" => true}))
      assert Enum.any?(children_a, &(&1 == %{"text" => " answer"}))

      # Check choice B has italic
      choice_b = Enum.find(json["choices"], &(&1["id"] == "B"))
      choice_b_content = choice_b["content"] |> List.first()
      children_b = choice_b_content["children"]
      assert Enum.any?(children_b, &(&1 == %{"text" => "An "}))
      assert Enum.any?(children_b, &(&1 == %{"text" => "incorrect", "em" => true}))
      assert Enum.any?(children_b, &(&1 == %{"text" => " answer"}))

      # Check choice C has code
      choice_c = Enum.find(json["choices"], &(&1["id"] == "C"))
      choice_c_content = choice_c["content"] |> List.first()
      children_c = choice_c_content["children"]
      assert Enum.any?(children_c, &(&1 == %{"text" => "Another "}))
      assert Enum.any?(children_c, &(&1 == %{"text" => "wrong", "code" => true}))
      assert Enum.any?(children_c, &(&1 == %{"text" => " answer"}))
    end

    test "preserves inline markup in hints" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Question?"
      choices:
        - id: "A"
          body_md: "Answer"
          score: 1
      hints:
        - body_md: "Remember that **bold** text is important"
        - body_md: "Also consider *italic* text"
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      part = List.first(json["authoring"]["parts"])
      hints = part["hints"]

      # First hint with bold
      hint1_content = Enum.at(hints, 0)["content"] |> List.first()
      hint1_children = hint1_content["children"]
      assert Enum.any?(hint1_children, &(&1 == %{"text" => "Remember that "}))
      assert Enum.any?(hint1_children, &(&1 == %{"text" => "bold", "strong" => true}))
      assert Enum.any?(hint1_children, &(&1 == %{"text" => " text is important"}))

      # Second hint with italic
      hint2_content = Enum.at(hints, 1)["content"] |> List.first()
      hint2_children = hint2_content["children"]
      assert Enum.any?(hint2_children, &(&1 == %{"text" => "Also consider "}))
      assert Enum.any?(hint2_children, &(&1 == %{"text" => "italic", "em" => true}))
      assert Enum.any?(hint2_children, &(&1 == %{"text" => " text"}))
    end

    test "preserves inline markup in feedback" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Question?"
      choices:
        - id: "A"
          body_md: "Answer"
          score: 1
          feedback_md: "**Correct!** This is the *right* answer."
        - id: "B"
          body_md: "Wrong"
          score: 0
          feedback_md: "This is `incorrect`."
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      part = List.first(json["authoring"]["parts"])
      responses = part["responses"]

      # Find response for choice A
      response_a = Enum.find(responses, &(&1["rule"] == "{A}"))
      feedback_a_content = response_a["feedback"]["content"] |> List.first()
      feedback_a_children = feedback_a_content["children"]

      assert Enum.any?(feedback_a_children, &(&1 == %{"text" => "Correct!", "strong" => true}))
      assert Enum.any?(feedback_a_children, &(&1 == %{"text" => " This is the "}))
      assert Enum.any?(feedback_a_children, &(&1 == %{"text" => "right", "em" => true}))
      assert Enum.any?(feedback_a_children, &(&1 == %{"text" => " answer."}))

      # Find response for choice B
      response_b = Enum.find(responses, &(&1["rule"] == "{B}"))
      feedback_b_content = response_b["feedback"]["content"] |> List.first()
      feedback_b_children = feedback_b_content["children"]

      assert Enum.any?(feedback_b_children, &(&1 == %{"text" => "This is "}))
      assert Enum.any?(feedback_b_children, &(&1 == %{"text" => "incorrect", "code" => true}))
      assert Enum.any?(feedback_b_children, &(&1 == %{"text" => "."}))
    end

    test "handles complex nested markup" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Choose the ***best*** option below:"
      choices:
        - id: "A"
          body_md: "Option with **bold *and italic* text**"
          score: 1
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)

      # Check stem has both bold and italic
      stem_content = json["stem"]["content"] |> List.first()
      stem_children = stem_content["children"]
      assert Enum.any?(stem_children, &(&1 == %{"text" => "Choose the "}))

      assert Enum.any?(stem_children, fn child ->
               Map.get(child, "text") == "best" &&
                 Map.get(child, "strong") == true &&
                 Map.get(child, "em") == true
             end)

      # Check choice has complex nesting
      choice_a = Enum.find(json["choices"], &(&1["id"] == "A"))
      choice_content = choice_a["content"] |> List.first()
      choice_children = choice_content["children"]

      # Verify the markup is preserved correctly
      assert Enum.any?(choice_children, &(&1 == %{"text" => "Option with "}))

      assert Enum.any?(choice_children, fn child ->
               Map.get(child, "text") == "bold " && Map.get(child, "strong") == true
             end)

      assert Enum.any?(choice_children, fn child ->
               Map.get(child, "text") == "and italic" &&
                 Map.get(child, "strong") == true &&
                 Map.get(child, "em") == true
             end)

      assert Enum.any?(choice_children, fn child ->
               Map.get(child, "text") == " text" && Map.get(child, "strong") == true
             end)
    end
  end
end
