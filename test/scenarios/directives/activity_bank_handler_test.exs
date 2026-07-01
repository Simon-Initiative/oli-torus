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
              title: "Copied Question"
              set:
                title: "Edited Copy"
                tags: ["review"]
          - delete:
              title: "Original Question"
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
    refute Map.has_key?(result.state.activities, {"bank_project", "Copied Question"})
    refute Map.has_key?(result.state.activity_virtual_ids, {"bank_project", "original_q"})
    assert Map.has_key?(result.state.activity_virtual_ids, {"bank_project", "copy_q"})
    assert result.state.activity_virtual_ids[{"bank_project", "copy_q"}].title == "Edited Copy"
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

  test "rejects duplicating non-banked activities into the activity bank" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        root:
          children:
            - page: "Practice"

    - create_activity:
        project: "bank_project"
        title: "Embedded Question"
        virtual_id: "embedded_q"
        scope: "embedded"
        type: "oli_multiple_choice"
        content: |
          stem_md: "Embedded?"
          choices:
            - id: "a"
              body_md: "Yes"
              score: 1

    - activity_bank:
        project: "bank_project"
        ops:
          - duplicate:
              virtual_id: "embedded_q"
              new_title: "Copied Embedded"
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert [{_directive, error}] = result.errors
    assert error =~ "is not banked"
  end

  test "duplicate preserves per-part objective mappings" do
    setup_yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        objectives:
          - "Objective A"
        root:
          children:
            - page: "Practice"
    """

    result = setup_yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()
    assert result.errors == []

    objective_id =
      result.state.projects["bank_project"].objectives_by_title["Objective A"].resource_id

    activity_yaml = """
    - activity_bank:
        project: "bank_project"
        ops:
          - create:
              title: "Mapped Question"
              virtual_id: "mapped_q"
              type: "oli_multiple_choice"
              objective_map:
                "1": [#{objective_id}]
              content: |
                stem_md: "Mapped?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
          - duplicate:
              virtual_id: "mapped_q"
              new_title: "Mapped Question Copy"
              new_virtual_id: "mapped_copy"
    """

    result =
      activity_yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute(state: result.state)

    assert result.errors == []

    assert result.state.activities[{"bank_project", "Mapped Question Copy"}].objectives == %{
             "1" => [objective_id]
           }
  end

  test "edit supports per-part objective mappings through objectives" do
    setup_yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        objectives:
          - "Objective A"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - create:
              title: "Mapped Question"
              virtual_id: "mapped_q"
              type: "oli_multiple_choice"
              content: |
                stem_md: "Mapped?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
    """

    result = setup_yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []

    objective_id =
      result.state.projects["bank_project"].objectives_by_title["Objective A"].resource_id

    part_id =
      result.state.activity_virtual_ids[{"bank_project", "mapped_q"}].content
      |> get_in(["authoring", "parts"])
      |> List.first()
      |> Map.fetch!("id")

    edit_yaml = """
    - activity_bank:
        project: "bank_project"
        ops:
          - edit:
              virtual_id: "mapped_q"
              set:
                objectives:
                  "#{part_id}": ["Objective A"]
    """

    result =
      edit_yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute(state: result.state)

    assert result.errors == []

    assert result.state.activities[{"bank_project", "Mapped Question"}].objectives == %{
             part_id => [objective_id]
           }
  end

  test "invalid list expectation shapes fail assertions without crashing" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - create:
              title: "Question"
              type: "oli_multiple_choice"
              content: |
                stem_md: "Question?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
          - query:
              name: "questions"
              expect:
                contains_titles: "Question"
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()

    assert result.errors == []
    assert [verification] = result.verifications
    refute verification.passed
    assert verification.message =~ "contains_titles expected"
  end

  test "supports numeric string resource_id references" do
    yaml = """
    - project:
        name: "bank_project"
        title: "Bank Project"
        root:
          children:
            - page: "Practice"

    - activity_bank:
        project: "bank_project"
        ops:
          - create:
              title: "Resource ID Question"
              virtual_id: "resource_q"
              type: "oli_multiple_choice"
              content: |
                stem_md: "Original?"
                choices:
                  - id: "a"
                    body_md: "Yes"
                    score: 1
    """

    result = yaml |> DirectiveParser.parse_yaml!() |> Engine.execute()
    assert result.errors == []

    resource_id = result.state.activity_virtual_ids[{"bank_project", "resource_q"}].resource_id

    edit_yaml = """
    - activity_bank:
        project: "bank_project"
        ops:
          - edit:
              resource_id: "#{resource_id}"
              set:
                title: "Edited By Resource String"
    """

    result =
      edit_yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute(state: result.state)

    assert result.errors == []
    assert Map.has_key?(result.state.activities, {"bank_project", "Edited By Resource String"})
  end
end
