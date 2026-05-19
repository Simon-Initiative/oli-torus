defmodule Oli.Dashboard.Oracle.ResultTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Oracle.Result

  describe "ok/3 and error/3" do
    # @ac "AC-004"
    test "returns contract-compliant success envelope with sanitized metadata" do
      result =
        Result.ok(:progress_summary, %{value: 88},
          version: 3,
          metadata: [
            duration_ms: 150,
            dashboard_product: :instructor_dashboard,
            nested_payload: %{raw: "redact"}
          ]
        )

      assert result.status == :ok
      assert result.oracle_key == :progress_summary
      assert result.oracle_version == 3
      assert result.payload == %{value: 88}
      assert result.metadata.duration_ms == 150
      assert result.metadata.dashboard_product == :instructor_dashboard
      assert result.metadata.nested_payload == :redacted
      refute Result.stale?(result)
    end

    test "returns contract-compliant error envelope and stale helper behavior" do
      result =
        Result.error(:progress_summary, {:timeout, :upstream},
          stale: true,
          metadata: %{
            attempt: 2,
            raw_list: [1, 2, 3]
          }
        )

      assert result.status == :error
      assert result.oracle_key == :progress_summary
      assert result.reason == {:timeout, :upstream}
      assert result.metadata.attempt == 2
      assert result.metadata.raw_list == :redacted
      assert Result.stale?(result)
      refute Result.stale?(%{})
    end
  end
end
