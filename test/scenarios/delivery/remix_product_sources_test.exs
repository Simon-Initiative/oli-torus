defmodule Oli.Scenarios.Delivery.RemixProductSourcesTest do
  use Oli.DataCase, async: true

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  test "community product sources can support a remix workflow" do
    result =
      Scenarios.execute_file(
        "test/scenarios/delivery/remix_product_sources.scenario.yaml",
        RuntimeOpts.build()
      )

    assert result.errors == [], "Scenario errors: #{inspect(result.errors)}"

    assert Enum.all?(result.verifications, & &1.passed),
           "Verifications: #{inspect(result.verifications)}"
  end
end
