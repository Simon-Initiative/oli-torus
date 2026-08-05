defmodule Oli.Delivery.Experiments.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Experiments.Telemetry

  @batch_completed_event [:oli, :experiments, :delivery_reward, :batch, :completed]
  @eligibility_completed_event [:oli, :experiments, :delivery_reward, :eligibility, :completed]

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

    test "ignores unrelated events" do
      assert :ok = Telemetry.handle_event([:other, :event], %{}, %{}, %{})
    end
  end

  describe "supervision" do
    test "the running application has attached the AppSignal handler" do
      handlers = :telemetry.list_handlers(@batch_completed_event)

      assert Enum.any?(handlers, &(&1.id == "experiment-reward-appsignal-handler"))
    end
  end
end
