defmodule Oli.Dashboard.Snapshot.AssemblerTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.Snapshot.Assembler

  describe "assemble/4" do
    # @ac "AC-001"
    test "assembles deterministic snapshot payloads and statuses from oracle envelopes" do
      context = context_input()

      oracle_results = [
        Result.ok(:oracle_instructor_progress, %{progress: 88},
          version: 2,
          metadata: %{source: :cache}
        ),
        Result.error(:oracle_instructor_support, {:timeout, :support_oracle},
          version: 1,
          metadata: %{source: :runtime}
        )
      ]

      assert {:ok, snapshot} =
               Assembler.assemble(context, "token-assembler-1", oracle_results,
                 expected_oracles: [
                   :oracle_instructor_progress,
                   :oracle_instructor_support,
                   :oracle_instructor_section_analytics
                 ]
               )

      assert snapshot.request_token == "token-assembler-1"
      assert snapshot.oracles.oracle_instructor_progress == %{progress: 88}
      refute Map.has_key?(snapshot.oracles, :oracle_instructor_support)
      assert snapshot.oracle_statuses.oracle_instructor_progress.status == :ready
      assert snapshot.oracle_statuses.oracle_instructor_support.status == :failed
      assert snapshot.oracle_statuses.oracle_instructor_support.reason_code == :projection_timeout
      assert snapshot.oracle_statuses.oracle_instructor_section_analytics.status == :unavailable
      assert snapshot.metadata.timezone == "Etc/UTC"
      assert snapshot.metadata.generated_at
      assert snapshot.metadata.container_type == :container
      assert snapshot.metadata.container_id == 99
    end
  end

  describe "merge_oracle_results/2" do
    test "deterministically merges by oracle key with incoming override" do
      existing =
        %{
          oracle_instructor_progress: Result.ok(:oracle_instructor_progress, %{progress: 10}),
          oracle_instructor_support:
            Result.error(:oracle_instructor_support, {:dependency_unavailable, :seed})
        }

      incoming = [
        Result.ok(:oracle_instructor_progress, %{progress: 95}),
        Result.ok(:oracle_instructor_engagement, %{engagement: :present})
      ]

      assert {:ok, merged} = Assembler.merge_oracle_results(existing, incoming)
      assert merged.oracle_instructor_progress.payload == %{progress: 95}
      assert merged.oracle_instructor_support.status == :error
      assert merged.oracle_instructor_engagement.status == :ok
    end
  end

  defp context_input do
    %{
      dashboard_context_type: :section,
      dashboard_context_id: 1001,
      user_id: 44,
      scope: %{container_type: :container, container_id: 99}
    }
  end
end
