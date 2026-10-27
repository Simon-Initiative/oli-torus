defmodule Oli.Scenarios.StudentDashboardCoverageScenarioTest do
  use Oli.DataCase

  alias Oli.Authoring.Collaborators
  alias Oli.Scenarios

  @scenario_path "assets/automation/tests/torus/student_delivery/student-dashboard-coverage.scenario.yaml"

  test "the accessibility seed succeeds and grants its author project access" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result =
      @scenario_path
      |> File.read!()
      |> String.replace("${RUN_ID}", "-#{System.unique_integer([:positive])}")
      |> Scenarios.execute_yaml()

    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)

    author = result.state.users["student_dashboard_coverage_author"]
    project = result.state.projects["student_dashboard_coverage_project"].project

    assert Collaborators.get_collaborator(author.id, project.id)
  end
end
