defmodule Oli.Delivery.Experiments.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Experiments.Telemetry

  @batch_completed_event [:oli, :experiments, :delivery_reward, :batch, :completed]
  @eligibility_completed_event [:oli, :experiments, :delivery_reward, :eligibility, :completed]
  @reward_failed_event [:oli, :experiments, :delivery_reward, :failed]
  describe "handle_event/4" do
    test "maps batch measurements to AppSignal metrics" do
      assert :ok =
               Telemetry.handle_event(
                 @batch_completed_event,
                 %{
                   duration_ms: 25,
                   attempt_count: 4,
                   context_count: 4,
                   failure_count: 1
                 },
                 %{status: :error},
                 %{}
               )
    end

    test "maps eligibility measurements to AppSignal metrics" do
      assert :ok =
               Telemetry.handle_event(
                 @eligibility_completed_event,
                 %{duration_ms: 8, assignment_count: 2, assignment_query_count: 1},
                 %{status: :matched},
                 %{}
               )
    end

    test "tolerates missing measurements and unknown status values" do
      assert :ok = Telemetry.handle_event(@batch_completed_event, %{}, %{}, %{})
      assert :ok = Telemetry.handle_event(@eligibility_completed_event, %{}, %{}, %{})
    end

    test "maps bounded reward outcomes" do
      assert :ok =
               Telemetry.handle_event(
                 [:oli, :experiments, :delivery_reward, :skipped],
                 %{count: 1},
                 %{reason: {:invalid_lifecycle_state, :abandoned}, learner_name: "private"},
                 %{}
               )
    end

    test "maps reward failures with bounded reasons" do
      assert :ok =
               Telemetry.handle_event(
                 @reward_failed_event,
                 %{count: 1},
                 %{reason: :lock_timeout, private_detail: "not a metric tag"},
                 %{}
               )

      assert :ok =
               Telemetry.handle_event(
                 @reward_failed_event,
                 %{},
                 %{reason: "unbounded failure detail"},
                 %{}
               )
    end

    test "ignores unrelated events" do
      assert :ok = Telemetry.handle_event([:other, :event], %{}, %{}, %{})
    end
  end

  describe "supervision" do
    test "the running application has attached the AppSignal handler" do
      handlers = :telemetry.list_handlers(@batch_completed_event)

      assert Enum.any?(handlers, &(&1.id == "experiment-reward-appsignal-handler"))

      failure_handlers = :telemetry.list_handlers(@reward_failed_event)
      assert Enum.any?(failure_handlers, &(&1.id == "experiment-reward-appsignal-handler"))
    end
  end
end
