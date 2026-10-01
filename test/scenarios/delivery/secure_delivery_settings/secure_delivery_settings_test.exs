defmodule Oli.Scenarios.SecureDeliverySettingsTest do
  use Oli.DataCase

  alias Oli.Scenarios

  @tag capture_log: true
  test "policy copy and publication refresh use real domain workflows" do
    path = Path.join(__DIR__, "policy.scenario.yaml")
    assert :ok = Scenarios.validate_file(path)
    result = Scenarios.execute_file(path, Oli.Scenarios.RuntimeOpts.build())
    assert result.errors == []
    assert Enum.all?(result.verifications, & &1.passed)
  end
end
