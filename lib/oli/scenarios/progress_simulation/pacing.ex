defmodule Oli.Scenarios.ProgressSimulation.Pacing do
  @moduledoc "Applies short fast-mode jitter or full real-time paced delays."

  @fast_minimum_ms 10
  @fast_jitter_ms 40

  @doc "Applies a small deterministic delay that staggers fast-mode learner actions."
  @spec fast_wait(non_neg_integer()) :: :ok
  def fast_wait(modeled_duration) do
    wait(@fast_minimum_ms + rem(modeled_duration, @fast_jitter_ms + 1))
  end

  @doc "Blocks the current learner worker for the modeled duration."
  @spec wait(non_neg_integer()) :: :ok
  def wait(0), do: :ok

  def wait(milliseconds) when is_integer(milliseconds) and milliseconds > 0 do
    Process.sleep(milliseconds)
    :ok
  end
end
