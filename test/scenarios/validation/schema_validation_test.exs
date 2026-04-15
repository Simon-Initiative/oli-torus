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
    """

    assert :ok = Scenarios.validate_yaml(yaml)
    directives = DirectiveParser.parse_yaml!(yaml)
    assert length(directives) == 9
  end
end
