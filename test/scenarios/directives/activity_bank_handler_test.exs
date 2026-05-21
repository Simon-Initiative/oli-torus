defmodule Oli.Scenarios.Directives.ActivityBankHandlerTest do
  use Oli.DataCase

  alias Oli.Scenarios.DirectiveParser
  alias Oli.Scenarios.Engine

  test "creates banked activities and queries with tag filters and expectations" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        tags:
          - "easy"
          - "hard"
        objectives:
          - "Understand basics"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - create:
              title: "Easy Question"
              virtual_id: "easy_q1"
              type: "oli_multiple_choice"
              tags: ["easy"]
              objectives: ["Understand basics"]
              content: |
                stem_md: "What is 2 + 2?"
                choices:
                  - id: "a"
                    body_md: "4"
                    score: 1
          - create:
              title: "Hard Question"
              virtual_id: "hard_q1"
              type: "oli_multiple_choice"
              tags: ["hard"]
              content: |
                stem_md: "What is 12 * 12?"
                choices:
                  - id: "a"
                    body_md: "144"
                    score: 1
          - query:
              name: "easy_questions"
              filters:
                tags:
                  contains: ["easy"]
              expect:
                total_count: 1
                titles: ["Easy Question"]
                not_titles: ["Hard Question"]
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    assert [verification] = result.verifications
    assert verification.passed
    assert Map.has_key?(result.state.activities, {"bank_project", "Easy Question"})
    assert Map.has_key?(result.state.activity_virtual_ids, {"bank_project", "easy_q1"})
    assert Map.has_key?(result.state.activity_bank_results, "easy_questions")
  end

  test "supports bulk create, duplicate, edit, delete, and stored-result assertions" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        tags:
          - "easy"
          - "review"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - create_bulk:
              activities:
                - title: "Original Question"
                  virtual_id: "original_q"
                  type: "oli_multiple_choice"
                  tags: ["easy"]
                  content: |
                    stem_md: "Original?"
                    choices:
                      - id: "a"
                        body_md: "Yes"
                        score: 1
          - duplicate:
              virtual_id: "original_q"
              new_title: "Copied Question"
              new_virtual_id: "copy_q"
          - edit:
              virtual_id: "copy_q"
              set:
                title: "Edited Copy"
                tags: ["review"]
          - delete:
              virtual_id: "original_q"
          - query:
              name: "review_questions"
              filters:
                tags:
                  contains: ["review"]
              expect:
                total_count: 1
                contains_titles: ["Edited Copy"]
                not_titles: ["Original Question"]
          - assert:
              result: "review_questions"
              expect:
                titles: ["Edited Copy"]
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    assert [verification] = result.verifications
    assert verification.passed
    assert Map.has_key?(result.state.activities, {"bank_project", "Edited Copy"})
    refute Map.has_key?(result.state.activity_virtual_ids, {"bank_project", "original_q"})
    assert Map.has_key?(result.state.activity_virtual_ids, {"bank_project", "copy_q"})
  end

  test "reports failed expectations as verification failures" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        tags:
          - "easy"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - query:
              name: "empty"
              filters:
                tags:
                  contains: ["easy"]
              expect:
                total_count: 2
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    assert [verification] = result.verifications
    refute verification.passed
    assert verification.message =~ "total_count expected 2"
  end
end
