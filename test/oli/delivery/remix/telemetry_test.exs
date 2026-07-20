defmodule Oli.Delivery.Remix.TelemetryTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Remix.Telemetry

  test "emits aggregate source selection and add outcome telemetry" do
    handler_id = "remix-telemetry-#{System.unique_integer([:positive])}"

    :ok =
      :telemetry.attach_many(
        handler_id,
        [[:oli, :delivery, :remix, :source_selected], [:oli, :delivery, :remix, :add_materials]],
        fn event, measurements, metadata, pid -> send(pid, {event, measurements, metadata}) end,
        self()
      )

    try do
      assert :ok = Telemetry.source_selected(:product)

      assert_receive {[:oli, :delivery, :remix, :source_selected], %{count: 1},
                      %{source_type: :product}}

      assert :ok = Telemetry.add_materials(2, [:product, :project, :product], :ok)

      assert_receive {[:oli, :delivery, :remix, :add_materials], %{selection_count: 2},
                      %{source_types: [:product, :project], outcome: :ok}}
    after
      :telemetry.detach(handler_id)
    end
  end
end
