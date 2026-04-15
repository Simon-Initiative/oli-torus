defmodule Oli.Scenarios.Delivery.AssessmentSettingsTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_dir Path.dirname(__ENV__.file)

  @scenario_paths @scenario_dir
                  |> Path.join("*.yaml")
                  |> Path.wildcard()
                  |> Enum.reject(&(Path.basename(&1) == "setup.yaml"))
                  |> Enum.sort()

  for path <- @scenario_paths do
    name =
      path
      |> Path.basename()
      |> String.replace_suffix(".scenario.yaml", "")
      |> String.replace_suffix(".yaml", "")
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
