defmodule Oli.Delivery.Proficiency.TelemetryTest do
  use ExUnit.Case, async: false

  alias Oli.Delivery.Proficiency.Telemetry
  alias Oli.Delivery.Proficiency.{Aggregate, Estimate}

  test "emits bounded stop metadata without learner or objective identifiers" do
    handler_id = "proficiency-provider-telemetry-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :delivery, :proficiency, :provider, :stop],
        fn _event, _measurements, metadata, parent -> send(parent, {:metadata, metadata}) end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert {:ok, %{}} =
             Telemetry.span(
               :lkt_aoa,
               :direct_objective,
               %{requested_user_count: 2, requested_objective_count: 3},
               fn -> {:ok, %{}} end
             )

    assert_receive {:metadata, metadata}

    assert Map.drop(metadata, [:telemetry_span_context]) == %{
             model: :lkt_aoa,
             operation: :direct_objective,
             requested_user_count: 2,
             requested_objective_count: 3,
             outcome: :ok,
             returned_count: 0,
             defined_count: 0,
             unavailable_count: 0
           }

    refute Map.has_key?(metadata, :section_id)
    refute Map.has_key?(metadata, :user_ids)
    refute Map.has_key?(metadata, :objective_ids)
  end

  test "counts non-empty canonical estimate and aggregate payloads" do
    estimate = %Estimate{
      section_id: 1,
      score: 0.5,
      label: :medium,
      learning_model_version: :naive
    }

    aggregate = %Aggregate{numeric_score: nil}

    assert {:ok, _} =
             capture_stop(
               fn ->
                 Telemetry.span(:naive, :direct_objective, %{}, fn ->
                   {:ok, %{1 => %{2 => estimate}}}
                 end)
               end,
               %{returned_count: 1, defined_count: 1, unavailable_count: 0}
             )

    assert {:ok, _} =
             capture_stop(
               fn ->
                 Telemetry.span(:lkt_aoa, :parent_objective, %{}, fn ->
                   {:ok, %{1 => aggregate}}
                 end)
               end,
               %{returned_count: 1, defined_count: 0, unavailable_count: 1}
             )
  end

  test "reports bounded metadata for returned errors and exceptions" do
    assert {:error, :unavailable} =
             capture_stop(
               fn ->
                 Telemetry.span(:lkt_aoa, :direct_objective, %{}, fn ->
                   {:error, :unavailable}
                 end)
               end,
               %{outcome: :error, returned_count: 0, defined_count: 0, unavailable_count: 0}
             )

    handler_id = "proficiency-provider-exception-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :delivery, :proficiency, :provider, :exception],
        fn _event, _measurements, metadata, _config ->
          send(parent, {:exception_metadata, metadata})
        end,
        nil
      )

    assert_raise RuntimeError, "provider failed", fn ->
      Telemetry.span(:lkt_aoa, :direct_objective, %{}, fn -> raise "provider failed" end)
    end

    assert_receive {:exception_metadata, metadata}
    assert metadata.outcome == :error
    assert metadata.returned_count == 0
    assert metadata.defined_count == 0
    assert metadata.unavailable_count == 0
    refute Map.has_key?(metadata, :user_ids)
    refute Map.has_key?(metadata, :objective_ids)
    :telemetry.detach(handler_id)
  end

  defp capture_stop(fun, expected_counts) do
    handler_id = "proficiency-provider-shape-#{System.unique_integer([:positive])}"
    parent = self()

    :ok =
      :telemetry.attach(
        handler_id,
        [:oli, :delivery, :proficiency, :provider, :stop],
        fn _event, _measurements, metadata, _config ->
          send(parent, {:shape_metadata, metadata})
        end,
        nil
      )

    try do
      result = fun.()
      assert_receive {:shape_metadata, metadata}
      assert Map.take(metadata, Map.keys(expected_counts)) == expected_counts
      result
    after
      :telemetry.detach(handler_id)
    end
  end
end
