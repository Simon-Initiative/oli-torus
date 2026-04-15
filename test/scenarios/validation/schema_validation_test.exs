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
