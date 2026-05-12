defmodule Oli.Scenarios.ActivitiesTest do
  @moduledoc """
  Test runner for activity-related scenarios.
  Automatically discovers and runs all .scenario.yaml files in this directory.
  """

  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @covered_activity_slugs MapSet.new([
                            "oli_check_all_that_apply",
                            "oli_custom_dnd",
                            "oli_directed_discussion",
                            "oli_file_upload",
                            "oli_image_coding",
                            "oli_image_hotspot",
                            "oli_likert",
                            "oli_logic_lab",
                            "oli_multi_input",
                            "oli_multiple_choice",
                            "oli_ordering",
                            "oli_response_multi",
                            "oli_short_answer",
                            "oli_vlab"
                          ])

  @scenario_dir Path.dirname(__ENV__.file)

  test "scenarios cover every registered activity except adaptive and embed" do
    registered_activity_slugs =
      Oli.Activities.list_activity_registrations()
      |> Enum.map(& &1.slug)
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(["oli_adaptive", "oli_embedded"]))

    assert MapSet.difference(registered_activity_slugs, @covered_activity_slugs) == MapSet.new()
  end

  for path <- Path.wildcard(Path.join(@scenario_dir, "*.scenario.yaml")) |> Enum.sort() do
    name =
      path
      |> Path.basename(".scenario.yaml")
      |> String.replace("_", " ")

    @scenario_path path
    test "scenario: #{name}" do
      assert :ok = Scenarios.validate_file(@scenario_path)

      result =
        Scenarios.execute_file(
          @scenario_path,
          RuntimeOpts.build()
        )

      assert result.errors == []

      failed_verifications =
        Enum.filter(result.verifications, fn verification -> !verification.passed end)

      assert failed_verifications == []
    end
  end
end
