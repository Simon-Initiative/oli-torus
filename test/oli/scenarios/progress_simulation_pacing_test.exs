defmodule Oli.Scenarios.ProgressSimulationPacingTest do
  use ExUnit.Case, async: true

  alias Oli.Scenarios.ProgressSimulation.Pacing

  test "wait blocks the learner worker for the requested duration" do
    started_at = System.monotonic_time(:millisecond)
    assert :ok = Pacing.wait(20)
    assert System.monotonic_time(:millisecond) - started_at >= 15
  end

  test "zero-duration waits return immediately" do
    assert :ok = Pacing.wait(0)
  end

  test "fast waits add a small deterministic action jitter" do
    started_at = System.monotonic_time(:millisecond)
    assert :ok = Pacing.fast_wait(23)
    elapsed = System.monotonic_time(:millisecond) - started_at

    assert elapsed >= 25
    assert elapsed < 500
  end
end
