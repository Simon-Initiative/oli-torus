defmodule Oli.Scenarios.LearningObjectives.PageElementWorkflowTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(__DIR__, "page_element_workflow.scenario.yaml")

  test "learning objectives page element follows authoring refresh, publish update, and delivery render workflow" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    result = Scenarios.execute_file(@scenario_path, RuntimeOpts.build())

    assert result.errors == []

    failed_verifications = Enum.reject(result.verifications, & &1.passed)

    assert failed_verifications == [],
           Enum.map_join(failed_verifications, "\n", & &1.message)

    assert length(result.verifications) == 1
  end
end
