defmodule Oli.Analytics.Summary.Pipeline do

  defstruct [
    :errors,
    :mark,
    :measurements,
    :attempt_group
  ]

  def init() do
    %__MODULE__{
      errors: [],
      mark:  Oli.Timing.mark(),
      measurements: %{},
      attempt_group: nil
    }
  end

  def step_done(%__MODULE__{mark: mark, measurements: measurements} = pipeline, recorded_as) do

    measurements = Map.put(measurements, recorded_as, Oli.Timing.elapsed(mark))

    pipeline
    |> Map.put(:measurements, measurements)
    |> Map.put(:mark, Oli.Timing.mark())
  end

  def all_done(%__MODULE__{measurements: measurements}) do
    :telemetry.execute([:oli, :analytics, :summary], measurements)
  end

end
