defmodule Oli.TorusDoc.PageParserTest do
  use ExUnit.Case, async: true
  alias Oli.TorusDoc.PageParser

  describe "parse/1" do
    test "parses a simple page with prose block" do
      yaml = """
      type: page
      id: simple-page
      title: Simple Page
      graded: false
      blocks:
        - type: prose
          body_md: |
            # Hello World
            This is a test.
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert page.type == "page"
      assert page.id == "simple-page"
      assert page.title == "Simple Page"
      assert page.graded == false
      assert length(page.blocks) == 1

      [prose_block] = page.blocks
      assert prose_block.type == "prose"
      assert prose_block.body_md =~ "# Hello World"
    end

    test "parses a page with survey block" do
      yaml = """
      type: page
      id: survey-page
      title: Survey Page
      blocks:
        - type: survey
          id: pre-survey
          title: Pre-Course Survey
          anonymous: true
          randomize: true
          paging: per-block
          show_progress: true
          intro_md: |
            Welcome to the survey
          blocks:
            - type: prose
              body_md: |
                ## Section 1
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert length(page.blocks) == 1

      [survey_block] = page.blocks
      assert survey_block.type == "survey"
      assert survey_block.id == "pre-survey"
      assert survey_block.title == "Pre-Course Survey"
      assert survey_block.anonymous == true
      assert survey_block.randomize == true
      assert survey_block.paging == "per-block"
      assert survey_block.show_progress == true
      assert survey_block.intro_md =~ "Welcome"

      assert length(survey_block.blocks) == 1
      [nested_prose] = survey_block.blocks
      assert nested_prose.type == "prose"
      assert nested_prose.body_md =~ "## Section 1"
    end

    test "handles multiple blocks" do
      yaml = """
      type: page
      id: multi-block
      title: Multi Block Page
      blocks:
        - type: prose
          body_md: First block
        - type: prose
          body_md: Second block
        - type: survey
          id: survey-1
          title: A Survey
          blocks: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert length(page.blocks) == 3

      [first, second, third] = page.blocks
      assert first.type == "prose"
      assert first.body_md == "First block"
      assert second.type == "prose"
      assert second.body_md == "Second block"
      assert third.type == "survey"
    end

    test "returns error for invalid YAML" do
      yaml = "not: valid: yaml: structure:"

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "YAML parsing failed"
    end

    test "returns error for missing page type" do
      yaml = """
      id: no-type
      title: Missing Type
      blocks: []
      """

      assert {:error, "Missing page type"} = PageParser.parse(yaml)
    end

    test "returns error for wrong page type" do
      yaml = """
      type: document
      id: wrong-type
      blocks: []
      """

      assert {:error, "Invalid page type: document, expected 'page'"} = PageParser.parse(yaml)
    end

    test "returns error for unknown block type" do
      yaml = """
      type: page
      id: unknown-block
      title: Unknown Block
      blocks:
        - type: unknown
          data: something
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Error in block 1"
      assert reason =~ "Unknown block type: unknown"
    end

    test "parses a group block with basic properties" do
      yaml = """
      type: page
      id: group-page
      title: Group Page
      blocks:
        - type: group
          id: group-1
          purpose: learnbydoing
          layout: vertical
          blocks:
            - type: prose
              body_md: Content in group
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert length(page.blocks) == 1

      [group] = page.blocks
      assert group.type == "group"
      assert group.id == "group-1"
      assert group.purpose == "learnbydoing"
      assert group.layout == "vertical"
      assert group.pagination_mode == "normal"

      assert length(group.blocks) == 1
      [prose] = group.blocks
      assert prose.type == "prose"
    end

    test "parses a group block with deck layout and pagination" do
      yaml = """
      type: page
      id: deck-page
      title: Deck Page
      blocks:
        - type: group
          id: deck-group
          purpose: walkthrough
          layout: deck
          pagination_mode: manualReveal
          blocks:
            - type: prose
              body_md: Slide 1
            - type: prose
              body_md: Slide 2
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [group] = page.blocks
      assert group.layout == "deck"
      assert group.pagination_mode == "manualReveal"
      assert length(group.blocks) == 2
    end

    test "validates group purpose" do
      yaml = """
      type: page
      id: bad-purpose
      title: Bad Purpose
      blocks:
        - type: group
          purpose: invalid_purpose
          blocks: []
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Invalid group purpose: invalid_purpose"
      assert reason =~ "Valid purposes:"
    end

    test "validates group layout" do
      yaml = """
      type: page
      id: bad-layout
      title: Bad Layout
      blocks:
        - type: group
          layout: invalid_layout
          blocks: []
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Invalid group layout: invalid_layout"
      assert reason =~ "Valid layouts: vertical, deck"
    end

    test "prevents nested groups" do
      yaml = """
      type: page
      id: nested-groups
      title: Nested Groups
      blocks:
        - type: group
          id: outer-group
          purpose: example
          layout: vertical
          blocks:
            - type: prose
              body_md: Before inner group
            - type: group
              id: inner-group
              purpose: checkpoint
              layout: deck
              blocks:
                - type: prose
                  body_md: Inside nested group
            - type: prose
              body_md: After inner group
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Groups cannot contain other groups"
    end

    test "prevents survey inside group" do
      yaml = """
      type: page
      id: group-with-survey
      title: Group with Survey
      blocks:
        - type: group
          purpose: quiz
          blocks:
            - type: prose
              body_md: Introduction
            - type: survey
              id: nested-survey
              title: Survey in Group
              blocks:
                - type: prose
                  body_md: Survey content
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Groups cannot contain surveys"
    end

    test "handles group with all valid purposes" do
      purposes = [
        "none",
        "checkpoint",
        "didigetthis",
        "labactivity",
        "learnbydoing",
        "learnmore",
        "manystudentswonder",
        "myresponse",
        "quiz",
        "simulation",
        "walkthrough",
        "example"
      ]

      for purpose <- purposes do
        yaml = """
        type: page
        id: #{purpose}-page
        title: #{purpose} Page
        blocks:
          - type: group
            purpose: #{purpose}
            blocks: []
        """

        assert {:ok, page} = PageParser.parse(yaml)
        [group] = page.blocks
        assert group.purpose == purpose
      end
    end

    test "uses default values when not specified" do
      yaml = """
      type: page
      id: defaults
      title: Defaults
      blocks:
        - type: group
          blocks: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [group] = page.blocks
      assert group.purpose == "none"
      assert group.layout == "vertical"
      assert group.pagination_mode == "normal"
      assert group.audience == nil
    end

    test "groups can contain only prose blocks" do
      yaml = """
      type: page
      id: group-with-prose
      title: Group with Prose Only
      blocks:
        - type: group
          purpose: example
          blocks:
            - type: prose
              body_md: First prose block
            - type: prose
              body_md: Second prose block
            - type: prose
              body_md: Third prose block
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [group] = page.blocks
      assert length(group.blocks) == 3

      for block <- group.blocks do
        assert block.type == "prose"
      end
    end

    test "returns error for prose block without body_md" do
      yaml = """
      type: page
      id: bad-prose
      title: Bad Prose
      blocks:
        - type: prose
          content: This should be body_md
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Prose block must have a 'body_md' field"
    end

    test "returns error for block without type" do
      yaml = """
      type: page
      id: no-block-type
      title: No Block Type
      blocks:
        - body_md: Missing type field
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Block must have a 'type' field"
    end

    test "parses activity blocks successfully" do
      yaml = """
      type: page
      id: activity-page
      title: Activity Page
      blocks:
        - type: activity
          activity:
            type: oli_multi_choice
            stem_md: "What is 2+2?"
            choices:
              - id: "a"
                body_md: "3"
                score: 0
              - id: "b"
                body_md: "4"
                score: 1
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert length(page.blocks) == 1
      
      [activity_block] = page.blocks
      assert activity_block.type == "activity_inline"
      assert activity_block.activity.type == "oli_multi_choice"
      assert activity_block.activity.stem_md == "What is 2+2?"
    end

    test "parses bank-selection blocks" do
      yaml = """
      type: page
      id: bank-page
      title: Bank Page
      blocks:
        - type: bank-selection
          id: bank-1
          count: 3
          points: 5
          clauses:
            - field: tags
              op: includes
              value: physics
            - field: type
              op: equals
              value: mcq
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [bank] = page.blocks
      assert bank.type == "bank_selection"
      assert bank.id == "bank-1"
      assert bank.count == 3
      assert bank.points == 5
      assert length(bank.clauses) == 2

      [clause1, clause2] = bank.clauses
      assert clause1.field == "tags"
      assert clause1.op == "includes"
      assert clause1.value == "physics"

      assert clause2.field == "type"
      assert clause2.op == "equals"
      assert clause2.value == "mcq"
    end

    test "bank-selection with defaults" do
      yaml = """
      type: page
      id: bank-page
      title: Bank Page
      blocks:
        - type: bank-selection
          clauses: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [bank] = page.blocks
      assert bank.count == 1
      assert bank.points == 0
      assert bank.clauses == []
    end

    test "bank-selection in survey" do
      yaml = """
      type: page
      id: survey-bank
      title: Survey with Bank
      blocks:
        - type: survey
          blocks:
            - type: bank-selection
              count: 2
              clauses:
                - field: difficulty
                  op: equals
                  value: easy
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [survey] = page.blocks
      [bank] = survey.blocks
      assert bank.type == "bank_selection"
      assert bank.count == 2
      assert length(bank.clauses) == 1
    end

    test "bank-selection in group" do
      yaml = """
      type: page
      id: group-bank
      title: Group with Bank
      blocks:
        - type: group
          purpose: quiz
          blocks:
            - type: bank-selection
              count: 5
              points: 10
              clauses: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [group] = page.blocks
      [bank] = group.blocks
      assert bank.type == "bank_selection"
      assert bank.count == 5
      assert bank.points == 10
    end

    test "parses activities and bank selections in surveys" do
      yaml = """
      type: page
      id: survey-with-activities
      title: Survey with Activities
      blocks:
        - type: survey
          id: survey-1
          title: Survey
          blocks:
            - type: prose
              body_md: Start
            - type: activity
              activity:
                type: oli_multi_choice
                stem_md: "Question?"
                choices:
                  - id: "a"
                    body_md: "Answer"
                    score: 1
            - type: bank-selection
              count: 2
              clauses:
                - field: "tags"
                  op: "includes"
                  value: "test"
            - type: prose
              body_md: End
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [survey] = page.blocks
      assert length(survey.blocks) == 4

      [first, second, third, fourth] = survey.blocks
      assert first.type == "prose"
      assert second.type == "activity_inline"
      assert second.activity.type == "oli_multi_choice"
      assert third.type == "bank_selection"
      assert fourth.type == "prose"
    end

    test "preserves metadata fields" do
      yaml = """
      type: page
      id: metadata-page
      title: Page with Metadata
      graded: true
      custom_field: custom_value
      another_field: 123
      blocks: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert page.metadata == %{"custom_field" => "custom_value", "another_field" => 123}
    end

    test "handles missing optional fields with defaults" do
      yaml = """
      type: page
      id: minimal
      title: Minimal Page
      blocks: []
      """

      assert {:ok, page} = PageParser.parse(yaml)
      assert page.graded == false
      assert page.metadata == nil
    end

    test "handles nested survey blocks correctly" do
      yaml = """
      type: page
      id: nested-survey
      title: Nested Survey
      blocks:
        - type: survey
          id: survey-1
          title: Survey
          blocks:
            - type: prose
              body_md: |
                ## Part 1
                Instructions
            - type: prose
              body_md: |
                ## Part 2
                More content
      """

      assert {:ok, page} = PageParser.parse(yaml)
      [survey] = page.blocks
      assert length(survey.blocks) == 2

      [part1, part2] = survey.blocks
      assert part1.body_md =~ "Part 1"
      assert part2.body_md =~ "Part 2"
    end

    test "reports error location in survey blocks" do
      yaml = """
      type: page
      id: survey-error
      title: Survey Error
      blocks:
        - type: survey
          id: survey-1
          title: Survey
          blocks:
            - type: prose
              body_md: Valid
            - type: unknown
              data: invalid
      """

      assert {:error, reason} = PageParser.parse(yaml)
      assert reason =~ "Error in block 1"
      assert reason =~ "Error in survey block 2"
      assert reason =~ "Unknown survey block type: unknown"
    end
  end
end
