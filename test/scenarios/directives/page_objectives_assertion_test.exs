defmodule Oli.Scenarios.Directives.Assert.PageObjectivesAssertionTest do
  use Oli.DataCase

  alias Oli.Resources
  alias Oli.Scenarios.{DirectiveParser, Engine}
  alias Oli.Scenarios.DirectiveTypes.AssertDirective
  alias Oli.Scenarios.Directives.AttemptSupport
  alias Oli.Scenarios.Directives.Assert.PageObjectivesAssertion

  test "returns a failed verification when attached objective ids cannot be resolved" do
    yaml = """
    - project:
        name: "objective_course"
        title: "Objective Course"
        root:
          children:
            - page: "Practice"

    - edit_page:
        project: "objective_course"
        page: "Practice"
        content: |
          title: "Practice"
          graded: false
          blocks:
            - type: prose
              body_md: "Practice page."

    - publish:
        to: "objective_course"
        description: "Publish objective course"

    - section:
        name: "objective_section"
        title: "Objective Section"
        from: "objective_course"
    """

    result =
      yaml
      |> DirectiveParser.parse_yaml!()
      |> Engine.execute()

    assert result.errors == []

    assert {:ok, page_revision} =
             AttemptSupport.get_page_revision(result.state, "objective_section", "Practice")

    assert {:ok, _revision} =
             Resources.update_revision(page_revision, %{objectives: %{"attached" => [-1]}})

    directive = %AssertDirective{
      page_objectives: %{
        section: "objective_section",
        page: "Practice",
        expected: []
      }
    }

    assert {:ok, _state, verification} = PageObjectivesAssertion.assert(directive, result.state)
    refute verification.passed
    assert verification.message =~ "Unresolved objective resource ids: [-1]"
    assert verification.actual == nil
  end
end
