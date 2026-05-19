defmodule Oli.Scenarios.CertificatesTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_dir Path.dirname(__ENV__.file)

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
