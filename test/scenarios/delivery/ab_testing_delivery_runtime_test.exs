defmodule Oli.Scenarios.Delivery.AbTestingDeliveryRuntimeTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  @scenario_path Path.join(
                   Path.dirname(__ENV__.file),
                   "ab_testing_delivery_runtime.scenario.yaml"
                 )

  test "scenario: native A/B testing delivery runtime" do
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
