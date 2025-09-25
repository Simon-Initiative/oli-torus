defmodule Oli.TorusDoc.PageConverterTest do
  use ExUnit.Case, async: true
  alias Oli.TorusDoc.PageConverter

  describe "to_torus_json/1" do
    test "converts simple prose page to Torus JSON" do
      parsed = %{
        type: "page",
        id: "test-page",
        title: "Test Page",
        graded: false,
        blocks: [
          %{
            type: "prose",
            body_md: "# Hello\n\nWorld",
            id: nil
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      assert json["type"] == "Page"
      assert json["id"] == "test-page"
      assert json["title"] == "Test Page"
      assert json["isGraded"] == false

      assert json["content"]["version"] == "0.1.0"
      assert is_list(json["content"]["model"])
      assert length(json["content"]["model"]) == 1

      [content_block] = json["content"]["model"]
      assert content_block["type"] == "content"
      assert is_list(content_block["children"])

      # Should have h1 and p from markdown
      assert length(content_block["children"]) == 2
      [h1, p] = content_block["children"]
      assert h1["type"] == "h1"
      assert p["type"] == "p"
    end

    test "converts survey block to Torus JSON" do
      parsed = %{
        type: "page",
        id: "survey-page",
        title: "Survey Page",
        graded: false,
        blocks: [
          %{
            type: "survey",
            id: "survey-1",
            title: "Pre-Survey",
            anonymous: true,
            randomize: true,
            paging: "per-block",
            show_progress: true,
            intro_md: "Welcome",
            blocks: [
              %{
                type: "prose",
                body_md: "## Section 1",
                id: nil
              }
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [survey] = json["content"]["model"]
      assert survey["type"] == "survey"
      assert survey["id"] == "survey-1"
      assert survey["title"] == "Pre-Survey"

      assert is_list(survey["children"])
      assert length(survey["children"]) == 1

      [content] = survey["children"]
      assert content["type"] == "content"
      [h2] = content["children"]
      assert h2["type"] == "h2"
    end

    test "generates IDs when missing" do
      parsed = %{
        type: "page",
        id: nil,
        title: nil,
        graded: false,
        blocks: [
          %{
            type: "prose",
            body_md: "Text",
            id: nil
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      assert String.starts_with?(json["id"], "gen_")
      assert json["title"] == "Untitled Page"

      [content] = json["content"]["model"]
      assert String.starts_with?(content["id"], "gen_")
    end

    test "converts multiple blocks" do
      parsed = %{
        type: "page",
        id: "multi",
        title: "Multi",
        graded: true,
        blocks: [
          %{
            type: "prose",
            body_md: "First",
            id: "prose-1"
          },
          %{
            type: "prose",
            body_md: "Second",
            id: "prose-2"
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      assert json["isGraded"] == true
      assert length(json["content"]["model"]) == 2

      [first, second] = json["content"]["model"]
      assert first["id"] == "prose-1"
      assert second["id"] == "prose-2"
    end

    test "handles inline activities" do
      parsed = %{
        type: "page",
        id: "activity-page",
        title: "Activity Page",
        graded: false,
        blocks: [
          %{
            type: "activity_inline",
            id: nil,
            activity: %{
              type: "oli_multi_choice",
              activity_type: :mcq,
              stem_md: "What is 2+2?",
              mcq_attributes: %{
                shuffle: false,
                choices: [
                  %{id: "a", body_md: "3", score: 0, feedback_md: nil},
                  %{id: "b", body_md: "4", score: 1, feedback_md: nil},
                  %{id: "c", body_md: "5", score: 0, feedback_md: nil}
                ]
              },
              hints: [],
              id: nil,
              title: nil,
              explanation_md: nil,
              incorrect_feedback_md: nil,
              objectives: [],
              tags: [],
              metadata: nil
            }
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [activity] = json["content"]["model"]
      assert activity["type"] == "activity-reference"
      assert activity["activitySlug"]
    end

    test "handles bank selections parsed from YAML" do
      # This test verifies that bank selections parsed by the parser
      # are correctly converted to Torus JSON format
      parsed = %{
        type: "page",
        id: "bank-page",
        title: "Bank Page",
        graded: false,
        blocks: [
          %{
            type: "bank_selection",
            id: nil,
            count: 1,
            points: 0,
            clauses: []
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [selection] = json["content"]["model"]
      assert selection["type"] == "selection"
      assert selection["count"] == 1
      # Not included when 0
      refute Map.has_key?(selection, "pointsPerActivity")
      assert selection["logic"]["conditions"]["children"] == []
    end

    test "includes required fields in output" do
      parsed = %{
        type: "page",
        id: "full-page",
        title: "Full Page",
        graded: false,
        blocks: [],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      # Check all required fields are present
      assert Map.has_key?(json, "type")
      assert Map.has_key?(json, "id")
      assert Map.has_key?(json, "title")
      assert Map.has_key?(json, "isGraded")
      assert Map.has_key?(json, "content")
      assert Map.has_key?(json, "objectives")
      assert Map.has_key?(json, "tags")
      assert Map.has_key?(json, "unresolvedReferences")

      assert json["objectives"]["attached"] == []
      assert json["tags"] == []
      assert json["unresolvedReferences"] == []
    end

    test "returns error for invalid markdown in prose" do
      parsed = %{
        type: "page",
        id: "bad-md",
        title: "Bad Markdown",
        graded: false,
        blocks: [
          %{
            type: "prose",
            # This will cause an error
            body_md: nil,
            id: nil
          }
        ],
        metadata: nil
      }

      assert {:error, reason} = PageConverter.to_torus_json(parsed)
      assert reason =~ "Failed to parse markdown"
    end

    test "from_yaml/1 integration test" do
      yaml = """
      type: page
      id: integration-test
      title: Integration Test
      graded: false
      blocks:
        - type: prose
          body_md: |
            # Test Page
            
            This is a **test** with:
            - Lists
            - Items
            
        - type: survey
          id: test-survey
          title: Test Survey
          blocks:
            - type: prose
              body_md: Question text
      """

      assert {:ok, json} = PageConverter.from_yaml(yaml)

      assert json["type"] == "Page"
      assert json["id"] == "integration-test"
      assert json["title"] == "Integration Test"
      assert json["isGraded"] == false

      assert length(json["content"]["model"]) == 2

      [prose, survey] = json["content"]["model"]
      assert prose["type"] == "content"
      assert survey["type"] == "survey"
      assert survey["id"] == "test-survey"
    end

    test "from_yaml/1 handles errors" do
      yaml = """
      type: wrong
      blocks: []
      """

      assert {:error, reason} = PageConverter.from_yaml(yaml)
      assert reason =~ "Invalid page type"
    end

    test "converts group block to Torus JSON" do
      parsed = %{
        type: "page",
        id: "group-page",
        title: "Group Page",
        graded: false,
        blocks: [
          %{
            type: "group",
            id: "group-1",
            purpose: "learnbydoing",
            layout: "vertical",
            pagination_mode: "normal",
            audience: nil,
            blocks: [
              %{
                type: "prose",
                body_md: "# Content",
                id: nil
              }
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [group] = json["content"]["model"]
      assert group["type"] == "group"
      assert group["id"] == "group-1"
      assert group["purpose"] == "learnbydoing"
      assert group["layout"] == "vertical"
      assert Map.has_key?(group, "children")

      # Should not include paginationMode when it's "normal" (default)
      refute Map.has_key?(group, "paginationMode")

      [content] = group["children"]
      assert content["type"] == "content"
    end

    test "includes paginationMode when not normal" do
      parsed = %{
        type: "page",
        id: "pagination-page",
        title: "Pagination Page",
        graded: false,
        blocks: [
          %{
            type: "group",
            id: "group-1",
            purpose: "walkthrough",
            layout: "deck",
            pagination_mode: "manualReveal",
            audience: nil,
            blocks: []
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [group] = json["content"]["model"]
      assert group["paginationMode"] == "manualReveal"
    end

    test "converts group with multiple prose blocks" do
      parsed = %{
        type: "page",
        id: "multi-prose",
        title: "Multi Prose",
        graded: false,
        blocks: [
          %{
            type: "group",
            id: "outer",
            purpose: "example",
            layout: "vertical",
            pagination_mode: "normal",
            audience: nil,
            blocks: [
              %{type: "prose", body_md: "First content", id: nil},
              %{type: "prose", body_md: "Second content", id: nil},
              %{type: "prose", body_md: "Third content", id: nil}
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [group] = json["content"]["model"]
      assert group["type"] == "group"
      assert group["purpose"] == "example"
      assert length(group["children"]) == 3

      for child <- group["children"] do
        assert child["type"] == "content"
      end
    end

    test "converts group with inline activities" do
      parsed = %{
        type: "page",
        id: "group-activity",
        title: "Group Activity",
        graded: false,
        blocks: [
          %{
            type: "group",
            id: "activity-group",
            purpose: "quiz",
            layout: "vertical",
            pagination_mode: "normal",
            audience: nil,
            blocks: [
              %{type: "prose", body_md: "Instructions", id: nil},
              %{
                type: "activity_inline",
                id: nil,
                activity: %{
                  type: "oli_multi_choice",
                  activity_type: :mcq,
                  stem_md: "Test question?",
                  mcq_attributes: %{
                    shuffle: false,
                    choices: [%{id: "a", body_md: "Answer", score: 1, feedback_md: nil}]
                  },
                  hints: [],
                  id: nil,
                  title: nil,
                  explanation_md: nil,
                  incorrect_feedback_md: nil,
                  objectives: [],
                  tags: [],
                  metadata: nil
                }
              },
              %{type: "prose", body_md: "Follow up", id: nil}
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [group] = json["content"]["model"]
      assert group["type"] == "group"
      assert group["purpose"] == "quiz"
      assert length(group["children"]) == 3

      [first, second, third] = group["children"]
      assert first["type"] == "content"
      # Activity becomes activity-reference
      assert second["type"] == "activity-reference"
      assert third["type"] == "content"
    end

    test "converts complex nested survey" do
      parsed = %{
        type: "page",
        id: "complex",
        title: "Complex",
        graded: false,
        blocks: [
          %{
            type: "survey",
            id: "survey-1",
            title: "Survey",
            anonymous: false,
            randomize: false,
            paging: "single",
            show_progress: false,
            intro_md: nil,
            blocks: [
              %{type: "prose", body_md: "Part 1", id: nil},
              %{
                type: "activity_inline",
                id: nil,
                activity: %{
                  type: "oli_short_answer",
                  activity_type: :short_answer,
                  stem_md: "Your answer?",
                  hints: [],
                  id: nil,
                  title: nil,
                  explanation_md: nil,
                  incorrect_feedback_md: nil,
                  objectives: [],
                  tags: [],
                  metadata: nil,
                  short_answer_attributes: %{
                    input_type: "text",
                    expected_length: 100
                  }
                }
              },
              %{type: "prose", body_md: "Part 2", id: nil},
              %{type: "bank_selection", id: nil, count: 2, points: 0, clauses: []}
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)

      [survey] = json["content"]["model"]
      assert length(survey["children"]) == 4

      [part1, activity, part2, bank] = survey["children"]
      assert part1["type"] == "content"
      # Now properly converted as activity-reference
      assert activity["type"] == "activity-reference"
      assert activity["activitySlug"]
      assert part2["type"] == "content"
      # Now properly converted
      assert bank["type"] == "selection"
    end

    test "converts bank selection to Torus JSON" do
      parsed = %{
        type: "page",
        id: "bank-test",
        title: "Bank Test",
        graded: false,
        blocks: [
          %{
            type: "bank_selection",
            id: "bank-1",
            count: 3,
            points: 5,
            clauses: [
              %{field: "tags", op: "includes", value: "physics"},
              %{field: "type", op: "equals", value: "mcq"}
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      [bank] = json["content"]["model"]

      assert bank["type"] == "selection"
      assert bank["id"] == "bank-1"
      assert bank["count"] == 3
      assert bank["pointsPerActivity"] == 5
      assert bank["children"] == nil

      logic = bank["logic"]
      assert logic["conditions"]["operator"] == "all"
      assert length(logic["conditions"]["children"]) == 2

      [cond1, cond2] = logic["conditions"]["children"]
      assert cond1["fact"] == "tags"
      assert cond1["operator"] == "contains"
      assert cond1["value"] == "physics"

      assert cond2["fact"] == "type"
      assert cond2["operator"] == "equal"
      assert cond2["value"] == "mcq"
    end

    test "converts bank selection with no points" do
      parsed = %{
        type: "page",
        id: "bank-test",
        title: "Bank Test",
        graded: false,
        blocks: [
          %{
            type: "bank_selection",
            id: "bank-2",
            count: 1,
            points: 0,
            clauses: []
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      [bank] = json["content"]["model"]

      assert bank["type"] == "selection"
      assert bank["count"] == 1
      refute Map.has_key?(bank, "pointsPerActivity")

      logic = bank["logic"]
      assert logic["conditions"]["children"] == []
    end

    test "converts bank selection in group" do
      parsed = %{
        type: "page",
        id: "group-bank",
        title: "Group Bank",
        graded: false,
        blocks: [
          %{
            type: "group",
            id: "group-1",
            purpose: "quiz",
            layout: "vertical",
            pagination_mode: "normal",
            audience: nil,
            blocks: [
              %{
                type: "bank_selection",
                id: "bank-in-group",
                count: 4,
                points: 10,
                clauses: []
              }
            ]
          }
        ],
        metadata: nil
      }

      assert {:ok, json} = PageConverter.to_torus_json(parsed)
      [group] = json["content"]["model"]
      [bank] = group["children"]

      assert bank["type"] == "selection"
      assert bank["count"] == 4
      assert bank["pointsPerActivity"] == 10
    end
  end
end
