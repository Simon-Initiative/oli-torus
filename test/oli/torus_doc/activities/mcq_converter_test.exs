defmodule Oli.TorusDoc.Activities.MCQConverterTest do
  use ExUnit.Case

  alias Oli.TorusDoc.ActivityParser
  alias Oli.TorusDoc.ActivityConverter

  describe "convert/1" do
    test "converts a complete MCQ activity to Torus JSON" do
      yaml = """
      type: "oli_multi_choice"
      id: "mcq123"
      title: "Sample MCQ"
      objectives: [123, 456]
      tags: [789]
      shuffle: true
      stem_md: "What is **2 + 2**?"
      choices:
        - id: "A"
          score: 0
          body_md: "3"
          feedback_md: "Incorrect. Try again."
        - id: "B"
          score: 5
          body_md: "4"
          feedback_md: "**Correct!**"
        - id: "C"
          score: 0
          body_md: "5"
      incorrect_feedback_md: "That's not right."
      hints:
        - body_md: "Think about addition."
        - body_md: "What is 1 + 1 + 1 + 1?"
      explanation_md: "2 + 2 = 4"
      """

      assert {:ok, parsed} = ActivityParser.parse(yaml)
      assert {:ok, json} = ActivityConverter.to_torus_json(parsed)

      assert json["type"] == "Activity"
      assert json["id"] == "mcq123"
      assert json["title"] == "Sample MCQ"
      assert json["activityType"] == "oli_multi_choice"

      # Check objectives and tags
      assert json["objectives"]["attached"] == [123, 456]
      assert json["tags"] == [789]

      # Check stem - verify it contains the expected text with bold
      stem_content = json["stem"]["content"] |> List.first()
      assert stem_content["type"] == "p"
      # The markdown parser formats bold as {"text": "...", "strong": true}
      # rather than as a nested element, which is acceptable
      assert length(stem_content["children"]) == 3
      assert Enum.at(stem_content["children"], 0)["text"] == "What is "
      assert Enum.at(stem_content["children"], 1)["text"] == "2 + 2"
      assert Enum.at(stem_content["children"], 1)["strong"] == true
      assert Enum.at(stem_content["children"], 2)["text"] == "?"

      # Check choices
      assert length(json["choices"]) == 3
      choice_a = Enum.find(json["choices"], &(&1["id"] == "A"))
      choice_content = choice_a["content"] |> List.first()
      assert choice_content["type"] == "p"
      assert choice_content["children"] == [%{"text" => "3"}]

      # Check authoring structure
      assert json["authoring"]["version"] == 2
      assert json["authoring"]["targeted"] == []
      assert length(json["authoring"]["parts"]) == 1

      # Check transformations
      assert length(json["authoring"]["transformations"]) == 1
      transform = List.first(json["authoring"]["transformations"])
      assert transform["path"] == "choices"
      assert transform["operation"] == "shuffle"
      assert transform["firstAttemptOnly"] == true

      # Check part
      part = List.first(json["authoring"]["parts"])
      assert part["scoringStrategy"] == "average"

      # Check responses
      responses = part["responses"]
      # Should have one response per choice plus catch-all
      assert length(responses) == 4

      # Check hints
      assert length(part["hints"]) == 2
      hint1 = Enum.at(part["hints"], 0)
      hint1_content = hint1["content"] |> List.first()
      assert hint1_content["type"] == "p"
      assert hint1_content["children"] == [%{"text" => "Think about addition."}]

      # Check explanation
      explanation_content = part["explanation"]["content"] |> List.first()
      assert explanation_content["type"] == "p"
      assert explanation_content["children"] == [%{"text" => "2 + 2 = 4"}]
    end

    test "converts MCQ with minimal fields" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Question?"
      choices:
        - id: "A"
          body_md: "Answer A"
          score: 0
        - id: "B"
          body_md: "Answer B"
          score: 1
      """

      assert {:ok, parsed} = ActivityParser.parse(yaml)
      assert {:ok, json} = ActivityConverter.to_torus_json(parsed)

      assert json["type"] == "Activity"
      assert json["activityType"] == "oli_multi_choice"
      assert json["title"] == nil
      refute Map.has_key?(json, "objectives")
      refute Map.has_key?(json, "tags")

      # Check stem content
      stem_content = json["stem"]["content"] |> List.first()
      assert stem_content["type"] == "p"
      assert stem_content["children"] == [%{"text" => "Question?"}]

      assert length(json["choices"]) == 2
      assert json["authoring"]["transformations"] == []

      part = List.first(json["authoring"]["parts"])
      assert part["hints"] == []
      refute Map.has_key?(part, "explanation")

      # Should still have catch-all response
      responses = part["responses"]
      catch_all = List.last(responses)
      assert catch_all["rule"] == ".*"
      assert catch_all["score"] == 0
    end

    test "handles markdown in choices and feedback" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Select the correct formula:"
      choices:
        - id: "A"
          body_md: "$$E = mc^2$$"
          score: 1
          feedback_md: "Correct! This is Einstein's famous equation."
        - id: "B"
          body_md: "$$F = ma$$"
          score: 0
          feedback_md: "This is Newton's second law, not what we're looking for."
      """

      assert {:ok, parsed} = ActivityParser.parse(yaml)
      assert {:ok, json} = ActivityConverter.to_torus_json(parsed)

      choice_a = Enum.find(json["choices"], &(&1["id"] == "A"))
      # The markdown parser doesn't parse $$ as math blocks currently,
      # it just preserves the text - this is a limitation we can improve later
      choice_content = choice_a["content"] |> List.first()
      assert choice_content["type"] == "p"
      # For now, verify the LaTeX is preserved in the text
      assert choice_content["children"] |> List.first() |> Map.get("text") =~ "E = mc^2"

      part = List.first(json["authoring"]["parts"])
      response_a = Enum.find(part["responses"], &(&1["rule"] == "input like {A}"))
      assert response_a["score"] == 1
      feedback_content = response_a["feedback"]["content"] |> List.first()
      assert feedback_content["type"] == "p"

      assert feedback_content["children"] == [
               %{"text" => "Correct! This is Einstein's famous equation."}
             ]
    end

    test "from_yaml convenience function" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Test?"
      choices:
        - id: "A"
          body_md: "Yes"
          score: 1
        - id: "B"
          body_md: "No"
          score: 0
      """

      assert {:ok, json} = ActivityConverter.from_yaml(yaml)
      assert json["type"] == "Activity"
      assert json["activityType"] == "oli_multi_choice"
      assert length(json["choices"]) == 2
    end
  end
end
