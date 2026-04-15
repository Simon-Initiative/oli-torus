defmodule Oli.Scenarios.Delivery.AssessmentSettingsTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts
  alias Oli.Scenarios.ScenarioRunner

  @scenario_dir Path.dirname(__ENV__.file)

  @scenarios ScenarioRunner.discover_scenarios(@scenario_dir,
               pattern: "*.yaml",
               exclude: ["setup.yaml"],
               include_metadata: true
             )

  for {name, path, metadata} <- @scenarios do
    name = String.replace(name, "_", " ")

    for tag <- metadata.tags do
      @tag String.to_atom(tag)
    end

    if metadata.timeout_ms do
      @tag timeout: metadata.timeout_ms
    end

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
