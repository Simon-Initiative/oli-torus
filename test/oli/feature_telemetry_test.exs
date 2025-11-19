defmodule Oli.FeatureTelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.FeatureTelemetry

  @event [:torus, :feature, :exec]

  describe "span/5" do
    test "emits start/stop events with merged metadata" do
      handler_id = unique_handler_id()

      attach(handler_id, [
        @event ++ [:start],
        @event ++ [:stop]
      ])

      fun = fn -> {:ok, :result} end

      assert {:ok, :result} ==
               FeatureTelemetry.span(
                 :canary_test_feature,
                 :five_percent,
                 :controller_action,
                 fun,
                 %{extra: "meta"}
               )

      assert_receive {:telemetry_event, [:torus, :feature, :exec, :start], _measurements,
                      start_meta}

      assert start_meta.feature == "canary_test_feature"
      assert start_meta.stage == "five_percent"
      assert start_meta.action == "controller_action"
      assert start_meta.extra == "meta"

      assert_receive {:telemetry_event, [:torus, :feature, :exec, :stop], measurements, stop_meta}
      assert is_integer(measurements.duration)
      assert stop_meta.ok? == true
      assert stop_meta.extra == "meta"

      detach(handler_id)
    end

    test "marks span as error for {:error, reason} results" do
      handler_id = unique_handler_id()

      attach(handler_id, [@event ++ [:stop]])

      assert {:error, :denied} ==
               FeatureTelemetry.span(:feature, "internal", "command", fn -> {:error, :denied} end)

      assert_receive {:telemetry_event, [:torus, :feature, :exec, :stop], _measurements, meta}
      refute meta.ok?

      detach(handler_id)
    end

    test "emits exception event and re-raises" do
      handler_id = unique_handler_id()

      attach(handler_id, [@event ++ [:exception]])

      assert_raise RuntimeError, "boom", fn ->
        FeatureTelemetry.span(:feature, "stage", "job", fn -> raise "boom" end)
      end

      assert_receive {:telemetry_event, [:torus, :feature, :exec, :exception], _measurements,
                      meta}

      assert %RuntimeError{message: "boom"} = meta.exception

      detach(handler_id)
    end
  end

  defp unique_handler_id do
    "feature-telemetry-test-#{System.unique_integer([:positive])}"
  end

  defp attach(handler_id, events) do
    parent = self()

    :telemetry.attach_many(
      handler_id,
      events,
      fn event_name, measurements, metadata, _ ->
        send(parent, {:telemetry_event, event_name, measurements, metadata})
      end,
      %{}
    )
  end

  defp detach(handler_id) do
    :telemetry.detach(handler_id)
  end
end
