defmodule Oli.LearningModel.LktAoa.TelemetryTest do
  use Oli.DataCase

  alias Oli.LearningModel
  alias Oli.LearningModel.Config
  alias Oli.LearningModel.LktAoa.Application, as: LktApplication
  alias Oli.LearningModel.LktAoaFixtures

  @events [
    [:oli, :learning_model, :lkt_aoa, :batch, :start],
    [:oli, :learning_model, :lkt_aoa, :batch, :stop],
    [:oli, :learning_model, :lkt_aoa, :batch, :exception]
  ]

  @forbidden_metadata_keys [
    :section_id,
    :user_id,
    :resource_id,
    :learning_objective_id,
    :activity_id,
    :activity_revision_id,
    :part_attempt_id,
    :part_attempt_guid,
    :attempt_guid,
    :part_id,
    :response,
    :score,
    :out_of,
    :sql,
    :binds,
    :exception,
    :stacktrace,
    :parameters,
    :learning_model_parameters
  ]

  test "emits start and stop telemetry with aggregate success metadata only" do
    %{section: section, group: group} = LktAoaFixtures.lkt_fixture()

    events =
      capture_events(fn ->
        assert {:ok, %{status: :applied}} = LearningModel.apply_evaluated_attempts(section, group)
      end)

    assert [
             %{event: [:oli, :learning_model, :lkt_aoa, :batch, :start]} = start_event,
             %{event: [:oli, :learning_model, :lkt_aoa, :batch, :stop]} = stop_event
           ] = events

    assert start_event.measurements.system_time
    assert start_event.metadata == %{model: :lkt_aoa, input_attempt_count: 1}

    assert is_integer(stop_event.measurements.duration)
    assert stop_event.measurements.duration >= 0

    assert stop_event.metadata == %{
             model: :lkt_aoa,
             result: :applied,
             failure_category: nil,
             input_attempt_count: 1,
             claimed_attempt_count: 1,
             contribution_count: 1,
             affected_state_count: 1,
             new_evidence_count: 1
           }

    refute_forbidden_metadata(stop_event.metadata)
  end

  test "duplicate retry emits bounded noop result metadata" do
    %{section: section, group: group} = LktAoaFixtures.lkt_fixture()

    assert {:ok, %{status: :applied}} = LearningModel.apply_evaluated_attempts(section, group)

    events =
      capture_events(fn ->
        assert {:ok, %{status: :noop}} = LearningModel.apply_evaluated_attempts(section, group)
      end)

    stop_event =
      Enum.find(events, &(&1.event == [:oli, :learning_model, :lkt_aoa, :batch, :stop]))

    assert stop_event.metadata.result == :noop
    assert stop_event.metadata.failure_category == nil
    assert stop_event.metadata.input_attempt_count == 1
    assert stop_event.metadata.claimed_attempt_count == 0
    assert stop_event.metadata.contribution_count == 0
    refute_forbidden_metadata(stop_event.metadata)
  end

  test "controlled validation failures emit bounded error categories without identifiers" do
    %{section: section, group: group} =
      LktAoaFixtures.lkt_fixture(%{part_attempts: [%{date_evaluated: nil}]})

    events =
      capture_events(fn ->
        assert {:error, {:missing_date_evaluated, _guid}} =
                 LearningModel.apply_evaluated_attempts(section, group)
      end)

    stop_event =
      Enum.find(events, &(&1.event == [:oli, :learning_model, :lkt_aoa, :batch, :stop]))

    assert stop_event.metadata.result == :error
    assert stop_event.metadata.failure_category == :invalid_input
    assert stop_event.metadata.input_attempt_count == 1
    refute_forbidden_metadata(stop_event.metadata)
  end

  test "unexpected exceptions emit bounded exception telemetry and re-raise" do
    %{section: section, group: group} = LktAoaFixtures.lkt_fixture()

    invalid_config = %Config{
      gamma: 0.1,
      rho: 1.0,
      recency_decay: 0.9,
      confidence_saturation: 0.0
    }

    events =
      capture_events(fn ->
        assert_raise ArithmeticError, fn ->
          LktApplication.apply(section, group, invalid_config)
        end
      end)

    exception_event =
      Enum.find(events, &(&1.event == [:oli, :learning_model, :lkt_aoa, :batch, :exception]))

    assert is_integer(exception_event.measurements.duration)

    assert exception_event.metadata == %{
             model: :lkt_aoa,
             result: :exception,
             failure_category: :exception,
             input_attempt_count: 1
           }

    refute_forbidden_metadata(exception_event.metadata)
  end

  defp capture_events(fun) do
    test_pid = self()
    handler_id = "lkt-aoa-telemetry-test-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        @events,
        fn event, measurements, metadata, _config ->
          send(
            test_pid,
            {:telemetry_event, %{event: event, measurements: measurements, metadata: metadata}}
          )
        end,
        nil
      )

    try do
      fun.()
    after
      :telemetry.detach(handler_id)
    end

    collect_events([])
  end

  defp collect_events(events) do
    receive do
      {:telemetry_event, event} -> collect_events(events ++ [event])
    after
      0 -> events
    end
  end

  defp refute_forbidden_metadata(metadata) do
    Enum.each(@forbidden_metadata_keys, fn key ->
      refute Map.has_key?(metadata, key), "forbidden telemetry metadata key present: #{key}"
    end)
  end
end
