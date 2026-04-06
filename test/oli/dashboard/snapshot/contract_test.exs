defmodule Oli.Dashboard.Snapshot.ContractTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Scope
  alias Oli.Dashboard.Snapshot.Contract

  describe "new_snapshot/1" do
    # @ac "AC-006"
    test "builds a canonical snapshot contract with explicit context and scope identity" do
      assert {:ok, snapshot} =
               Contract.new_snapshot(%{
                 request_token: "token-1",
                 context: %{
                   dashboard_context_type: :section,
                   dashboard_context_id: 777,
                   user_id: 12,
                   scope: %{container_type: :container, container_id: 1001}
                 },
                 metadata: %{timezone: "UTC"},
                 projection_statuses: %{
                   summary: %{status: :ready},
                   student_support: %{status: :failed, reason: {:timeout, :proficiency_oracle}}
                 }
               })

      assert snapshot.snapshot_version == Contract.current_snapshot_version()
      assert snapshot.projection_version == Contract.current_projection_version()
      assert snapshot.request_token == "token-1"
      assert %Scope{container_type: :container, container_id: 1001} = snapshot.scope
      assert snapshot.metadata.dashboard_context_type == :section
      assert snapshot.metadata.dashboard_context_id == 777
      assert snapshot.metadata.container_type == :container
      assert snapshot.metadata.container_id == 1001
      assert snapshot.metadata.timezone == "UTC"
      assert snapshot.projection_statuses.summary.status == :ready
      assert snapshot.projection_statuses.student_support.status == :failed
      assert snapshot.projection_statuses.student_support.reason_code == :projection_timeout
    end

    test "rejects metadata identity mismatch against context/scope" do
      assert {:error,
              {:invalid_snapshot_contract, {:metadata_identity_mismatch, :container_id, _}}} =
               Contract.new_snapshot(%{
                 request_token: "token-1",
                 context: %{
                   dashboard_context_type: :section,
                   dashboard_context_id: 777,
                   user_id: 12,
                   scope: %{container_type: :course, container_id: nil}
                 },
                 metadata: %{container_id: 999}
               })
    end

    # @ac "AC-007"
    test "rejects unsupported contract versions" do
      assert {:error, {:invalid_snapshot_contract, {:unsupported_snapshot_version, 2}}} =
               Contract.new_snapshot(%{
                 snapshot_version: 2,
                 request_token: "token-1",
                 context: %{
                   dashboard_context_type: :section,
                   dashboard_context_id: 777,
                   user_id: 12
                 }
               })
    end
  end

  describe "new_projection_status/1" do
    test "accepts ready status without reason code" do
      assert {:ok, %{status: :ready}} = Contract.new_projection_status(:ready)
    end

    test "requires reason code for failed-like statuses and deterministically infers from reason" do
      assert {:ok, status} =
               Contract.new_projection_status(%{
                 status: :failed,
                 reason: {:missing_oracle_payload, :progress_oracle}
               })

      assert status.reason_code == :missing_oracle_payload
    end

    test "supports string-keyed status maps and rejects export-only reason codes" do
      assert {:ok, status} =
               Contract.new_projection_status(%{
                 "status" => :partial,
                 "reason" => {:dependency_unavailable, :proficiency_oracle}
               })

      assert status.status == :partial
      assert status.reason_code == :dependency_unavailable

      assert {:error, {:invalid_snapshot_contract, {:invalid_reason_code, :zip_build_failed}}} =
               Contract.new_projection_status(%{
                 status: :failed,
                 reason_code: :zip_build_failed
               })
    end

    test "rejects invalid status" do
      assert {:error, {:invalid_snapshot_contract, {:invalid_projection_status_type, :loading}}} =
               Contract.new_projection_status(%{status: :loading})
    end
  end

  describe "version and reason-code helpers" do
    test "compatibility helpers return deterministic version support" do
      assert Contract.compatible_versions?(1, 1)
      assert Contract.compatible_snapshot_version?("1")
      assert Contract.compatible_projection_version?(1)
      refute Contract.compatible_versions?(2, 1)
      refute Contract.compatible_projection_version?("abc")
    end

    test "reason code taxonomy and classifiers are deterministic" do
      assert :projection_timeout == Contract.projection_reason_code({:timeout, :oracle})
      assert :projection_derivation_failed == Contract.projection_reason_code(:unexpected)

      assert :required_projection_failed ==
               Contract.export_reason_code({:required_projection_failed, :summary})

      assert :export_failed == Contract.export_reason_code(:unexpected)

      assert :projection_timeout in Contract.reason_codes(:projection)
      assert :zip_build_failed in Contract.reason_codes(:export)
    end
  end
end
