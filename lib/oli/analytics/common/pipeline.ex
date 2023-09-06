defmodule Oli.Analytics.Common.Pipeline do

  require Logger

  defstruct [
    :errors,
    :mark,
    :measurements,
    :data,
    :label
  ]

  def init(label) do
    %__MODULE__{
      errors: [],
      mark:  Oli.Timing.mark(),
      measurements: %{},
      data: nil,
      label: label
    }
  end

  def step_done(%__MODULE__{mark: nil, measurements: nil} = pipeline, _), do: pipeline
  def step_done(%__MODULE__{mark: mark, measurements: measurements} = pipeline, recorded_as) do

    measurements = Map.put(measurements, recorded_as, Oli.Timing.elapsed(mark))

    pipeline
    |> Map.put(:measurements, measurements)
    |> Map.put(:mark, Oli.Timing.mark())
  end

  def all_done(%__MODULE__{measurements: nil}), do: nil
  def all_done(%__MODULE__{measurements: measurements, errors: errors, label: label} = pipeline) do
    :telemetry.execute([:oli, :analytics, :summary], measurements)

    Logger.info("#{label} pipeline complete, measurements: #{to_friendly_display(measurements)}, errors: #{inspect(errors)}}}")

    case errors do
      [] -> {:ok, pipeline}
      _ -> {:error, pipeline}
    end
  end

  def add_error(%__MODULE__{errors: errors} = pipeline, error) do
    %{pipeline | errors: [error | errors]}
  end

  defp to_friendly_display(measurements) do
    Enum.map(measurements, fn {k, v} -> "#{k}: #{Float.round(v / 1000 / 1000, 2)}ms" end)
    |> Enum.join(", ")
  end

end
