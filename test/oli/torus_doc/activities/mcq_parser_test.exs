defmodule Oli.TorusDoc.Activities.MCQParserTest do
  use ExUnit.Case

  alias Oli.TorusDoc.ActivityParser

  describe "parse/1" do
    test "parses a complete MCQ activity" do
      yaml = """
      type: "oli_multi_choice"
      title: "Sample MCQ"
      objectives: [123, 456]
      tags: [789]
      shuffle: true
      stem_md: |
        What is 2 + 2?
      choices:
        - id: "A"
          score: 0
          body_md: "3"
          feedback_md: "Incorrect. Try again."
        - id: "B"
          score: 1
          body_md: "4"
          feedback_md: "Correct!"
        - id: "C"
          score: 0
          body_md: "5"
      incorrect_feedback_md: "That's not right."
      hints:
        - body_md: "Think about addition."
        - body_md: "What is 1 + 1 + 1 + 1?"
      explanation_md: |
        2 + 2 = 4 is a basic arithmetic fact.
      """

      assert {:ok, activity} = ActivityParser.parse(yaml)

      assert activity.type == "oli_multi_choice"
      assert activity.title == "Sample MCQ"
      assert activity.objectives == [123, 456]
      assert activity.tags == [789]
      assert activity.stem_md == "What is 2 + 2?\n"
      assert activity.explanation_md == "2 + 2 = 4 is a basic arithmetic fact.\n"
      assert activity.incorrect_feedback_md == "That's not right."

      assert activity.activity_type == :mcq
      assert activity.mcq_attributes.shuffle == true

      choices = activity.mcq_attributes.choices
      assert length(choices) == 3

      assert Enum.at(choices, 0).id == "A"
      assert Enum.at(choices, 0).score == 0
      assert Enum.at(choices, 0).body_md == "3"
      assert Enum.at(choices, 0).feedback_md == "Incorrect. Try again."

      assert Enum.at(choices, 1).id == "B"
      assert Enum.at(choices, 1).score == 1
      assert Enum.at(choices, 1).body_md == "4"
      assert Enum.at(choices, 1).feedback_md == "Correct!"

      assert Enum.at(choices, 2).id == "C"
      assert Enum.at(choices, 2).score == 0
      assert Enum.at(choices, 2).body_md == "5"
      assert Enum.at(choices, 2).feedback_md == nil

      hints = activity.hints
      assert length(hints) == 2
      assert Enum.at(hints, 0).body_md == "Think about addition."
      assert Enum.at(hints, 1).body_md == "What is 1 + 1 + 1 + 1?"
    end

    test "parses MCQ with minimal fields" do
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

      assert {:ok, activity} = ActivityParser.parse(yaml)

      assert activity.type == "oli_multi_choice"
      assert activity.title == nil
      assert activity.objectives == []
      assert activity.tags == []
      assert activity.stem_md == "Question?"
      assert activity.explanation_md == nil
      assert activity.incorrect_feedback_md == nil

      assert activity.mcq_attributes.shuffle == false
      assert length(activity.mcq_attributes.choices) == 2
      assert activity.hints == []
    end

    test "handles decimal scores" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Question?"
      choices:
        - id: "A"
          body_md: "Partial"
          score: 0.5
        - id: "B"
          body_md: "Correct"
          score: 1.0
      """

      assert {:ok, activity} = ActivityParser.parse(yaml)

      choices = activity.mcq_attributes.choices
      assert Enum.at(choices, 0).score == 0.5
      assert Enum.at(choices, 1).score == 1.0
    end

    test "errors on missing required fields" do
      yaml = """
      type: "oli_multi_choice"
      """

      assert {:error, _} = ActivityParser.parse(yaml)
    end

    test "errors on invalid choice structure" do
      yaml = """
      type: "oli_multi_choice"
      stem_md: "Question?"
      choices:
        - body_md: "Missing ID"
      """

      assert {:error, reason} = ActivityParser.parse(yaml)
      assert reason =~ "Choice must have 'id'"
    end

    test "errors on unsupported activity type" do
      yaml = """
      type: "unknown_activity"
      stem_md: "Question?"
      """

      assert {:error, reason} = ActivityParser.parse(yaml)
      assert reason =~ "Unsupported activity type"
    end
  end
end
