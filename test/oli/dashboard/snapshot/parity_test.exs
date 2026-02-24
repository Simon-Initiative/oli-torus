defmodule Oli.Dashboard.Snapshot.ParityTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Parity

  describe "fingerprint/2" do
    # @ac "AC-002"
    test "is deterministic across dataset ordering" do
      snapshot_bundle = snapshot_bundle_fixture()

      specs_a = [%{dataset_id: :progress}, %{dataset_id: :summary}]
      specs_b = [%{dataset_id: :summary}, %{dataset_id: :progress}]

      assert Parity.fingerprint(snapshot_bundle, specs_a) ==
               Parity.fingerprint(snapshot_bundle, specs_b)
    end
  end

  describe "compare/2" do
    # @ac "AC-002"
    test "returns match for identical parity fingerprints" do
      snapshot_bundle = snapshot_bundle_fixture()
      expected = Parity.fingerprint(snapshot_bundle, [%{dataset_id: :summary}])

      assert :match = Parity.compare(expected, expected)
    end

    test "returns mismatch details for differing fingerprints" do
      assert {:mismatch, %{expected: "abc", actual: "xyz"}} = Parity.compare("abc", "xyz")
    end
  end

  defp snapshot_bundle_fixture do
    %{
      request_token: "parity-token-1",
      snapshot: %{snapshot_version: 1, projection_version: 1},
      projection_statuses: %{
        summary: %{status: :ready},
        progress: %{status: :partial, reason_code: :dependency_unavailable}
      }
    }
  end
end
