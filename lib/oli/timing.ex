defmodule Oli.Timing do
  @doc """
  Runs a function and times its execution.
  Returns a tuple of the form `{time, result}` where time
  is the time in `microseconds` and `result` is the return
  result of the function.

  ## Examples

      iex> run(fn -> "3" end)
      {2, "3"}

      iex> run(fn a, b-> a <> b end, ["Bob", " Ross"])
      {3, "Bob Ross"}

  """
  def run(func) do
    :timer.tc(func)
  end

  def run(func, args) do
    :timer.tc(func, args)
  end

  @doc """
  Emits a telemetry event for the given tags and measurement.
  Designed to be used in conjunction with `Oli.Timing.run`.

  ## Examples

      iex> run(fn -> "4" end) |> emit([:oli, :four, :calc], :duration)
      "4"

  """
  def emit({time, return_result}, tags, measurement_atom) do
    :telemetry.execute(tags, Map.put(%{}, measurement_atom, time / 1000))

    return_result
  end
end
