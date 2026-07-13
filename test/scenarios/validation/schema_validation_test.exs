defmodule Oli.Scenarios.Validation.SchemaValidationTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.DirectiveParser

  test "all checked-in scenario yaml files satisfy scenario.schema.json" do
    files =
      Path.wildcard("test/scenarios/**/*.yaml")
      |> Enum.sort()

    failures =
      Enum.reduce(files, [], fn file, acc ->
        case Scenarios.validate_file(file) do
          :ok ->
            acc

          {:error, errors} ->
            [{file, errors} | acc]
        end
      end)
      |> Enum.reverse()

    assert failures == [],
           "Schema validation failures:\n" <>
             Enum.map_join(failures, "\n\n", fn {file, errors} ->
               "#{file}\n  " <>
                 Enum.map_join(errors, "\n  ", fn err ->
                   "#{err.path}: #{err.message}"
                 end)
             end)
  end

  test "schema and parser agree on unknown directives" do
    yaml = """
    - create_project:
        name: "demo"
    """

    assert {:error, _errors} = Scenarios.validate_yaml(yaml)

    assert_raise RuntimeError, ~r/Unrecognized directive: 'create_project'/, fn ->
      DirectiveParser.parse_yaml!(yaml)
    end
  end

  test "schema and parser accept section scheduling dates" do
    yaml = """
    - section:
        name: "scheduled_section"
        start_date: "2026-01-01T00:00:00Z"
        end_date: "2026-12-31T23:59:59Z"
    """

    assert :ok = Scenarios.validate_yaml(yaml)

    [section] = DirectiveParser.parse_yaml!(yaml)
    assert section.start_date == ~U[2026-01-01 00:00:00Z]
    assert section.end_date == ~U[2026-12-31 23:59:59Z]
  end

  test "schema accepts phase 2 gating directives" do
    yaml = """
    - project:
        name: "demo"
        title: "Demo"
        root:
          children:
            - page: "Source"
            - page: "Locked"

    - section:
        name: "demo_section"
        from: "demo"

    - user:
        name: "alice"
        type: "student"

    - time:
        at: "2026-01-10T12:00:00Z"

    - gate:
        name: "demo_gate"
        section: "demo_section"
        target: "Locked"
        type: "started"
        source: "Source"

    - visit_page:
        student: "alice"
        section: "demo_section"
        page: "Source"

    - assert:
        gating:
          gate: "demo_gate"
          type: "started"
          target: "Locked"
          source: "Source"
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    assert length(directives) == 7
  end

  test "schema accepts objective authoring and objective assertions" do
    yaml = """
    - project:
        name: "demo"
        root:
          children:
            - page: "Practice"

    - objectives:
        project: "demo"
        ops:
          - create:
              title: "Understand systems"
          - create_sub:
              parent: "Understand systems"
              title: "Predict behavior"
          - remove_sub:
              parent: "Understand systems"
              title: "Predict behavior"

    - edit_page:
        project: "demo"
        page: "Practice"
        objectives:
          - "Understand systems"
        content: |
          title: "Practice"
          blocks:
            - type: prose
              body_md: "Practice."

    - assert:
        page_objectives:
          section: "demo_section"
          page: "Practice"
          expected:
            - "Understand systems"

    - assert:
        activity_objectives:
          project: "demo"
          activity_virtual_id: "q1"
          expected:
            - "Predict behavior"
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    assert length(directives) == 5
  end

  test "schema accepts finalize_attempt and gradebook assertions" do
    yaml = """
    - project:
        name: "demo"
        title: "Demo"
        root:
          children:
            - page: "Quiz Page"

    - edit_page:
        project: "demo"
        page: "Quiz Page"
        content: |
          title: "Quiz Page"
          graded: true
          blocks:
            - type: activity
              virtual_id: "quiz_q1"
              activity:
                type: oli_multiple_choice
                stem_md: "What is 2 + 2?"
                choices:
                  - id: "a"
                    body_md: "3"
                    score: 0
                  - id: "b"
                    body_md: "4"
                    score: 1

    - section:
        name: "demo_section"
        from: "demo"

    - user:
        name: "instructor_1"
        type: "instructor"

    - user:
        name: "student_1"
        type: "student"

    - visit_page:
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"

    - start_attempt:
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"
        password: "secret"
        expect: "incorrect_password"

    - answer_question:
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"
        activity_virtual_id: "quiz_q1"
        response: "b"

    - finalize_attempt:
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"

    - assert:
        gradebook:
          instructor: "instructor_1"
          section: "demo_section"
          student: "student_1"
          page: "Quiz Page"
          score: 1.0
          out_of: 1.0
          was_late: false

    - assert:
        review_attempt:
          section: "demo_section"
          student: "student_1"
          page: "Quiz Page"
          allow_review: true
          activities_visible: true
          answers_visible: true
          feedback_visible: true
          scores_visible: true
          activity_count: 1

    - assert:
        activity_attempt:
          section: "demo_section"
          student: "student_1"
          page: "Quiz Page"
          activity_virtual_id: "quiz_q1"
          activity_lifecycle_state: "evaluated"
          part_lifecycle_state: "evaluated"
          score: 1.0
          out_of: 1.0
          part_score: 1.0
          part_out_of: 1.0
          response: "b"
          answerable: false
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    assert length(directives) == 12
  end

  test "schema and parser accept activity_bank directives" do
    yaml = """
    - activity_bank:
        project: "demo"
        ops:
          - create:
              title: "Easy Question"
              virtual_id: "easy_q1"
              type: "oli_multiple_choice"
              tags: ["easy", 42]
              objectives: ["Understand basics"]
              content: |
                stem_md: "What is 2 + 2?"
                choices:
                  - id: "a"
                    body_md: "4"
                    score: 1
          - create_bulk:
              activities:
                - title: "Bulk Question"
                  activity_type_slug: "oli_multiple_choice"
                  content_format: "json"
                  content:
                    stem: "Bulk"
          - query:
              name: "easy_questions"
              filters:
                tags:
                  contains: ["easy"]
              paging:
                limit: 5
                offset: 0
              expect:
                total_count: 1
                titles: ["Easy Question"]
          - edit:
              virtual_id: "easy_q1"
              set:
                title: "Updated Easy Question"
          - duplicate:
              virtual_id: "easy_q1"
              new_title: "Copy of Easy Question"
              new_virtual_id: "easy_q1_copy"
          - delete:
              virtual_id: "easy_q1_copy"
          - assert:
              result: "easy_questions"
              expect:
                contains_titles: ["Easy Question"]
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    [directive] = DirectiveParser.parse_yaml!(yaml)

    assert directive.project == "demo"
    assert length(directive.ops) == 7
  end

  test "schema and parser accept instructor_customization directives and assertions" do
    yaml = """
    - instructor_customization:
        section: "demo_section"
        page: "Practice"
        actor: "instructor_1"
        ops:
          - exclude_activity:
              activity_virtual_id: "embedded_q1"
          - restore_activity:
              activity_virtual_id: "embedded_q1"
          - exclude_bank_selection:
              selection_id: "selection_1"
          - restore_bank_selection:
              selection_id: "selection_1"
          - exclude_bank_candidate:
              selection_id: "selection_1"
              activity_virtual_id: "banked_q1"
          - restore_bank_candidate:
              selection_id: "selection_1"
              activity_virtual_id: "banked_q1"

    - assert:
        activity_customization:
          section: "demo_section"
          page: "Practice"
          embedded_activities:
            - activity_virtual_id: "embedded_q1"
              enabled: true
          bank_selections:
            - selection_id: "selection_1"
              enabled: true
          bank_candidates:
            - selection_id: "selection_1"
              activity_virtual_id: "banked_q1"
              enabled: true

    - assert:
        activity_attempt:
          section: "demo_section"
          student: "student_1"
          page: "Practice"
          activity_virtual_id: "embedded_q1"
          exists: false
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    [directive, customization_assertion, attempt_assertion] = DirectiveParser.parse_yaml!(yaml)

    assert directive.section == "demo_section"
    assert length(directive.ops) == 6
    assert customization_assertion.activity_customization.page == "Practice"
    assert attempt_assertion.activity_attempt.exists == false
  end

  test "schema accepts assessment settings student_exception directives" do
    yaml = """
    - student_exception:
        action: "set"
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"
        set:
          max_attempts: 2
          time_limit: 30
          due_date: "2026-01-10T12:00:00Z"

    - student_exception:
        action: "remove"
        student: "student_1"
        section: "demo_section"
        page: "Quiz Page"
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    assert length(directives) == 2
  end

  test "schema accepts optional scenario metadata and wait directives" do
    yaml = """
    scenario:
      tags:
        - nightly
        - slow
        - real_time
      timeout_ms: 300000
      reason: "Exercises real elapsed time behavior."

    directives:
      - wait:
          seconds: 1
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    metadata = Oli.Scenarios.Metadata.from_yaml(yaml)

    assert length(directives) == 1
    assert metadata.tags == ["nightly", "slow", "real_time"]
    assert metadata.timeout_ms == 300_000
  end
end
