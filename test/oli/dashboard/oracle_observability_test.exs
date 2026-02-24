defmodule Oli.Dashboard.OracleObservabilityTest do
  use ExUnit.Case, async: true

  alias Oli.Dashboard.Oracle.Result
  alias Oli.Dashboard.OracleRegistry
  alias Oli.Dashboard.OracleRegistry.Validator
  alias Oli.Dashboard.TestOracles.DependentA
  alias Oli.Dashboard.TestOracles.Prerequisite

  @resolve_stop_event [:oli, :dashboard, :oracles, :registry, :resolve, :stop]
  @lookup_stop_event [:oli, :dashboard, :oracles, :registry, :lookup, :stop]
  @validation_error_event [:oli, :dashboard, :oracles, :registry, :validation, :error]
  @contract_error_event [:oli, :dashboard, :oracles, :contract, :error]

  describe "registry telemetry events" do
    test "emits resolve stop event with deterministic metadata" do
      handler = attach_telemetry([@resolve_stop_event])

      assert {:ok, %{required: [:oracle_dep_a], optional: []}} =
               OracleRegistry.dependencies_for(registry(), :progress_summary)

      assert_receive {:telemetry_event, @resolve_stop_event, measurements, metadata}
      assert is_integer(measurements.duration_ms)
      assert metadata.dashboard_product == :instructor_dashboard
      assert metadata.consumer_key == :progress_summary
      assert metadata.outcome == :ok
      assert metadata.error_type == "none"
      assert metadata.event == "resolve"

      :telemetry.detach(handler)
    end

    test "emits lookup stop event for unknown oracle errors" do
      handler = attach_telemetry([@lookup_stop_event])

      assert {:error, {:unknown_oracle, :missing_oracle}} =
               OracleRegistry.oracle_module(registry(), :missing_oracle)

      assert_receive {:telemetry_event, @lookup_stop_event, measurements, metadata}
      assert is_integer(measurements.duration_ms)
      assert metadata.dashboard_product == :instructor_dashboard
      assert metadata.oracle_key == :missing_oracle
      assert metadata.outcome == :unknown_oracle
      assert metadata.error_type == "unknown_oracle"
      assert metadata.event == "lookup"

      :telemetry.detach(handler)
    end
  end

  describe "validator telemetry events" do
    test "emits validation error events with typed error tags" do
      handler = attach_telemetry([@validation_error_event])

      assert {:error,
              {:invalid_dependency_profile,
               {:undeclared_oracle, :progress_summary, :missing_oracle}}} =
               Validator.validate(invalid_registry())

      assert_receive {:telemetry_event, @validation_error_event, measurements, metadata}
      assert measurements.count == 1
      assert metadata.dashboard_product == :instructor_dashboard
      assert metadata.outcome == :error
      assert metadata.error_type == "invalid_dependency_profile"
      assert metadata.event == "validation"

      :telemetry.detach(handler)
    end
  end

  describe "contract telemetry events" do
    test "emits contract error event with pii-safe metadata" do
      handler = attach_telemetry([@contract_error_event])

      _result =
        Result.error(:oracle_dep_a, {:upstream_timeout, %{raw: "sensitive"}},
          metadata: %{
            dashboard_product: :instructor_dashboard,
            user_id: 123,
            request_payload: %{email: "sensitive@example.com"}
          }
        )

      assert_receive {:telemetry_event, @contract_error_event, measurements, metadata}
      assert measurements.count == 1
      assert metadata.dashboard_product == :instructor_dashboard
      assert metadata.oracle_key == :oracle_dep_a
      assert metadata.outcome == :error
      assert metadata.error_type == "upstream_timeout"
      assert metadata.event == "contract"

      assert Enum.sort(Map.keys(metadata)) ==
               Enum.sort([
                 :consumer_key,
                 :dashboard_product,
                 :error_type,
                 :event,
                 :oracle_key,
                 :outcome
               ])

      :telemetry.detach(handler)
    end
  end

  defp registry do
    %{
      dashboard_product: :instructor_dashboard,
      consumers: %{
        progress_summary: %{required: [:oracle_dep_a], optional: []}
      },
      oracles: %{
        oracle_dep_a: DependentA,
        oracle_prereq: Prerequisite
      }
    }
  end

  defp invalid_registry do
    %{
      dashboard_product: :instructor_dashboard,
      consumers: %{
        progress_summary: %{required: [:missing_oracle], optional: []}
      },
      oracles: %{
        oracle_dep_a: DependentA,
        oracle_prereq: Prerequisite
      }
    }
  end

  defp attach_telemetry(events) do
    handler_id = "oracle-observability-test-#{System.unique_integer([:positive])}"
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
