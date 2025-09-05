defmodule Oli.TorusDoc.PageWithActivityTest do
  use ExUnit.Case

  alias Oli.TorusDoc.PageParser
  alias Oli.TorusDoc.PageConverter

  describe "pages with activities" do
    test "parses and converts a page with an inline MCQ activity" do
      yaml = """
      type: "page"
      id: "page1"
      title: "Quiz Page"
      graded: true
      blocks:
        - type: "prose"
          body_md: |
            ## Introduction
            Let's test your knowledge.
        
        - type: "activity"
          id: "activity1"
          activity_type: "oli_multi_choice"
          stem_md: "What is 2 + 2?"
          choices:
            - id: "A"
              score: 0
              body_md: "3"
            - id: "B"
              score: 1
              body_md: "4"
            - id: "C"
              score: 0
              body_md: "5"
          shuffle: true
        
        - type: "prose"
          body_md: "Good luck!"
      """

      assert {:ok, parsed} = PageParser.parse(yaml)
      assert parsed.type == "page"
      assert parsed.id == "page1"
      assert parsed.title == "Quiz Page"
      assert parsed.graded == true
      assert length(parsed.blocks) == 3

      # Check the activity block
      activity_block = Enum.at(parsed.blocks, 1)
      assert activity_block.type == "activity_inline"
      assert activity_block.activity.type == "oli_multi_choice"
      assert activity_block.activity.stem_md == "What is 2 + 2?"
      assert length(activity_block.activity.mcq_attributes.choices) == 3

      # Convert to Torus JSON
      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      assert json["type"] == "Page"
      assert json["id"] == "page1"
      assert json["title"] == "Quiz Page"
      assert json["isGraded"] == true

      # Check content model
      model = json["content"]["model"]
      assert length(model) == 3

      # First block should be prose content
      assert Enum.at(model, 0)["type"] == "content"

      # Second block should be activity reference
      activity_ref = Enum.at(model, 1)
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] != nil

      # The inline activity should be attached
      assert Map.has_key?(activity_ref, "_inline_activity")
      inline_activity = activity_ref["_inline_activity"]
      assert inline_activity["type"] == "Activity"
      assert inline_activity["activityType"] == "oli_multi_choice"
      assert length(inline_activity["choices"]) == 3

      # Third block should be prose content
      assert Enum.at(model, 2)["type"] == "content"
    end

    test "parses and converts a page with activity reference" do
      yaml = """
      type: "page"
      id: "page2"
      title: "Reference Page"
      blocks:
        - type: "prose"
          body_md: "Complete this activity:"
        
        - type: "activity"
          id: "ref1"
          activity_id: "existing_mcq_123"
        
        - type: "prose"
          body_md: "Thank you!"
      """

      assert {:ok, parsed} = PageParser.parse(yaml)

      # Check the activity reference block
      activity_block = Enum.at(parsed.blocks, 1)
      assert activity_block.type == "activity_reference"
      assert activity_block.activity_id == "existing_mcq_123"

      # Convert to Torus JSON
      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      model = json["content"]["model"]
      activity_ref = Enum.at(model, 1)
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] == "existing_mcq_123"
      refute Map.has_key?(activity_ref, "_inline_activity")
    end

    test "handles activities in groups" do
      yaml = """
      type: "page"
      title: "Group with Activity"
      blocks:
        - type: "group"
          purpose: "learnbydoing"
          blocks:
            - type: "prose"
              body_md: "Try this:"
            
            - type: "activity"
              activity_type: "oli_multi_choice"
              stem_md: "Question?"
              choices:
                - id: "A"
                  body_md: "Answer"
                  score: 1
      """

      assert {:ok, parsed} = PageParser.parse(yaml)
      group = List.first(parsed.blocks)
      assert group.type == "group"
      assert length(group.blocks) == 2

      activity_block = Enum.at(group.blocks, 1)
      assert activity_block.type == "activity_inline"

      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      model = json["content"]["model"]
      group_json = List.first(model)
      assert group_json["type"] == "group"
      assert length(group_json["children"]) == 2

      activity_ref = Enum.at(group_json["children"], 1)
      assert activity_ref["type"] == "activity-reference"
      assert Map.has_key?(activity_ref, "_inline_activity")
    end

    test "handles activities in surveys" do
      yaml = """
      type: "page"
      title: "Survey with Activity"
      blocks:
        - type: "survey"
          title: "Knowledge Check"
          blocks:
            - type: "prose"
              body_md: "Answer this:"
            
            - type: "activity"
              activity_id: "survey_question_1"
      """

      assert {:ok, parsed} = PageParser.parse(yaml)
      survey = List.first(parsed.blocks)
      assert survey.type == "survey"
      assert length(survey.blocks) == 2

      activity_block = Enum.at(survey.blocks, 1)
      assert activity_block.type == "activity_reference"
      assert activity_block.activity_id == "survey_question_1"

      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      model = json["content"]["model"]
      survey_json = List.first(model)
      assert survey_json["type"] == "survey"
      assert length(survey_json["children"]) == 2

      activity_ref = Enum.at(survey_json["children"], 1)
      assert activity_ref["type"] == "activity-reference"
      assert activity_ref["activitySlug"] == "survey_question_1"
    end

    test "errors on invalid activity definition" do
      yaml = """
      type: "page"
      blocks:
        - type: "activity"
          # Missing both stem_md and activity_id
          id: "bad_activity"
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "must have either"
    end
  end
end
