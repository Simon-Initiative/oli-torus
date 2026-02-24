defmodule Oli.InstructorDashboard.DataSnapshot.CsvExportTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Snapshot.Parity
  alias Oli.InstructorDashboard.DataSnapshot.CsvExport

  @export_stop_event [:oli, :dashboard, :snapshot, :export, :stop]
  @parity_check_event [:oli, :dashboard, :snapshot, :parity, :check]

  defmodule DeterministicSerializer do
    def serialize(snapshot_bundle, dataset_spec) do
      dataset_id = Map.fetch!(dataset_spec, :dataset_id)
      projection = Map.get(snapshot_bundle.projections, dataset_id)

      send(self(), {:serialize_called, dataset_id, projection})

      {:ok, "field,value\n#{dataset_id},#{inspect(projection)}\n"}
    end
  end

  defmodule FailingSerializer do
    def serialize(_snapshot_bundle, _dataset_spec), do: {:error, :serializer_failed}
  end

  describe "build_zip/2" do
    # @ac "AC-003"
    test "builds zip and manifest from transform-only snapshot inputs" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}, progress: %{active: 11}},
          %{summary: %{status: :ready}, progress: %{status: :ready}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :fail_closed, DeterministicSerializer),
        dataset_spec(:progress, [:progress], :fail_closed, DeterministicSerializer)
      ]

      assert {:ok, zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: dataset_specs})

      assert manifest.request_token == snapshot_bundle.request_token
      assert manifest.snapshot_version == 1
      assert manifest.projection_version == 1
      assert manifest.export_profile == :default
      assert manifest.parity.fingerprint == Parity.fingerprint(snapshot_bundle, manifest.datasets)
      assert manifest.parity.comparison.status == :not_checked
      assert Enum.map(manifest.datasets, & &1.dataset_id) == [:summary, :progress]
      assert Enum.all?(manifest.datasets, &(&1.status == :included))

      assert_receive {:serialize_called, :summary, %{students: 17}}
      assert_receive {:serialize_called, :progress, %{active: 11}}

      entries = unzip_to_memory(zip_binary)
      assert Map.has_key?(entries, ~c"summary.csv")
      assert Map.has_key?(entries, ~c"progress.csv")
      assert Map.has_key?(entries, ~c"manifest.json")
    end

    # @ac "AC-004"
    test "includes partial dataset when policy allows partial with manifest" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :partial, reason_code: :dependency_unavailable}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :allow_partial_with_manifest, DeterministicSerializer)
      ]

      assert {:ok, _zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: dataset_specs})

      assert [%{dataset_id: :summary, status: :included, projection_state: :partial}] =
               manifest.datasets
    end

    # @ac "AC-004"
    test "excludes dataset when projection is failed and policy allows partial" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{},
          %{summary: %{status: :failed, reason_code: :projection_derivation_failed}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :allow_partial_with_manifest, DeterministicSerializer)
      ]

      assert {:ok, zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: dataset_specs})

      assert [%{dataset_id: :summary, status: :excluded, reason_code: :dataset_policy_excluded}] =
               manifest.datasets

      entries = unzip_to_memory(zip_binary)
      refute Map.has_key?(entries, ~c"summary.csv")
      assert Map.has_key?(entries, ~c"manifest.json")
    end

    # @ac "AC-005"
    test "fails closed with deterministic reason code for partial required projection" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :partial, reason_code: :dependency_unavailable}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :fail_closed, DeterministicSerializer)
      ]

      assert {:error, {:export_failed, :required_projection_failed, details}} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: dataset_specs})

      assert details.dataset_id == :summary
    end

    # @ac "AC-005"
    test "fails closed with deterministic reason code for unavailable required projection" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{},
          %{summary: %{status: :unavailable, reason_code: :missing_oracle_payload}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :fail_closed, DeterministicSerializer)
      ]

      assert {:error, {:export_failed, :required_projection_unavailable, details}} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: dataset_specs})

      assert details.dataset_id == :summary
    end

    test "applies serializer failure policy deterministically" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :ready}}
        )

      fail_closed_spec = [dataset_spec(:summary, [:summary], :fail_closed, FailingSerializer)]

      assert {:error, {:export_failed, :serializer_error, details}} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: fail_closed_spec})

      assert details.dataset_id == :summary

      partial_spec = [
        dataset_spec(:summary, [:summary], :allow_partial_with_manifest, FailingSerializer)
      ]

      assert {:ok, _zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: partial_spec})

      assert [%{dataset_id: :summary, status: :excluded, reason_code: :serializer_error}] =
               manifest.datasets
    end

    test "validates custom dataset spec shape before export" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :ready}}
        )

      invalid_specs = [%{dataset_id: :summary}]

      assert {:error, {:export_failed, :export_failed, details}} =
               CsvExport.build_zip(snapshot_bundle, %{dataset_specs: invalid_specs})

      assert {:invalid_dataset_spec, {:missing_keys, missing_keys}} = details.reason
      assert :serializer_module in missing_keys
    end

    # @ac "AC-002"
    test "attaches parity comparison metadata and emits parity/export telemetry" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :ready}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :fail_closed, DeterministicSerializer)
      ]

      expected_fingerprint = Parity.fingerprint(snapshot_bundle, [%{dataset_id: :summary}])
      handler = attach_telemetry([@export_stop_event, @parity_check_event])

      assert {:ok, _zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{
                 export_profile: :instructor_dashboard,
                 expected_parity_fingerprint: expected_fingerprint,
                 dataset_specs: dataset_specs
               })

      assert manifest.parity.comparison.status == :match
      assert manifest.parity.comparison.expected_fingerprint == expected_fingerprint
      assert manifest.parity.comparison.actual_fingerprint == manifest.parity.fingerprint

      assert_receive {:telemetry_event, @parity_check_event, %{count: 1}, parity_metadata}
      assert parity_metadata.status == :match
      assert parity_metadata.export_profile == :instructor_dashboard
      assert parity_metadata.expected_present == true
      assert parity_metadata.dataset_count == 1
      assert parity_metadata.mismatch_count == 0

      assert_receive {:telemetry_event, @export_stop_event, %{duration_ms: duration_ms},
                      export_metadata}

      assert is_integer(duration_ms)
      assert duration_ms >= 0
      assert export_metadata.outcome == :ok
      assert export_metadata.export_profile == :instructor_dashboard
      assert export_metadata.dataset_count == 1
      assert export_metadata.included_count == 1
      assert export_metadata.excluded_count == 0

      :telemetry.detach(handler)
    end

    test "records parity mismatch details when expected fingerprint differs" do
      snapshot_bundle =
        snapshot_bundle_fixture(
          %{summary: %{students: 17}},
          %{summary: %{status: :ready}}
        )

      dataset_specs = [
        dataset_spec(:summary, [:summary], :fail_closed, DeterministicSerializer)
      ]

      handler = attach_telemetry([@parity_check_event])

      assert {:ok, _zip_binary, manifest} =
               CsvExport.build_zip(snapshot_bundle, %{
                 expected_parity_fingerprint: "mismatched-fingerprint",
                 dataset_specs: dataset_specs
               })

      assert manifest.parity.comparison.status == :mismatch
      assert manifest.parity.comparison.expected_fingerprint == "mismatched-fingerprint"

      assert_receive {:telemetry_event, @parity_check_event, %{count: 1}, parity_metadata}
      assert parity_metadata.status == :mismatch
      assert parity_metadata.reason_code == :parity_mismatch
      assert parity_metadata.mismatch_count == 1

      :telemetry.detach(handler)
    end
  end

  describe "boundary guardrails" do
    # @ac "AC-003"
    test "csv export modules do not reference direct query/coordinator internals" do
      module_paths = [
        "lib/oli/instructor_dashboard/data_snapshot/csv_export.ex",
        "lib/oli/instructor_dashboard/data_snapshot/dataset_registry.ex",
        "lib/oli/instructor_dashboard/data_snapshot/csv_export/serializers/map_rows.ex"
      ]

      for path <- module_paths do
        content = File.read!(path)

        refute String.contains?(content, "Oli.Dashboard.LiveDataCoordinator")
        refute String.contains?(content, "Oli.Dashboard.DataCache")
        refute String.contains?(content, "Oli.Dashboard.DataCoordinator")
        refute String.contains?(content, "Repo.")
        refute String.contains?(content, "Ecto.Query")
        refute String.contains?(content, "Oli.Analytics")
      end
    end
  end

  defp dataset_spec(dataset_id, required_projections, failure_policy, serializer_module) do
    %{
      dataset_id: dataset_id,
      filename: "#{dataset_id}.csv",
      required_projections: required_projections,
      optional_projections: [],
      serializer_module: serializer_module,
      failure_policy: failure_policy
    }
  end

  defp snapshot_bundle_fixture(projections, projection_statuses) do
    %{
      request_token: "csv-token-1",
      snapshot: %{snapshot_version: 1, projection_version: 1},
      projections: projections,
      projection_statuses: projection_statuses
    }
  end

  defp unzip_to_memory(zip_binary) do
    zip_filename =
      Path.join(
        System.tmp_dir!(),
        "data_snapshot_csv_export_#{System.unique_integer([:positive])}.zip"
      )

    File.write!(zip_filename, zip_binary)

    {:ok, entries} = :zip.unzip(String.to_charlist(zip_filename), [:memory])
    File.rm!(zip_filename)

    Map.new(entries)
  end

  defp attach_telemetry(events) do
    handler_id = "csv-export-test-#{System.unique_integer([:positive])}"
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _config ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )

    handler_id
  end
end
