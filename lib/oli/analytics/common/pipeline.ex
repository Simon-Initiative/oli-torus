defmodule Oli.Analytics.Common.Pipeline do
  @moduledoc """
  A reusable, multi-step pipeline that can be used with arbitrary multi-step
  operations.  The Pipeline will track the time spent in each step and report
  the results to telemetry and to system Logger.  It will also track errors
  that occur in the pipeline.  General usage is to create a labelled pipeline,
  then call step_done/2 after each step, and finally call all_done/1 when the
  entire pipeline is finished.  For example:alarm_handler

  ```
  Pipeline.init("My Pipeline")
  |> process_message_batch()
  |> Pipeline.step_done(:process_message_batch)
  |> upsert_summary_records()
  |> Pipeline.step_done(:upsert_summary_records)
  |> save_state_to_s3()
  |> Pipeline.step_done(:save_state_to_s3)
  |> Pipeline.all_done()
  ```

  Or, if you have your actual functions call the step_done/2 functions, you can
  get something more concise:

  ```
  Pipeline.init("My Pipeline")
  |> process_message_batch()
  |> upsert_summary_records()
  |> save_state_to_s3()
  |> Pipeline.all_done()
  ```

  """

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
      mark: Oli.Timing.mark(),
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

    Logger.info(
      "#{label} pipeline complete, measurements: #{to_friendly_display(measurements)}, errors: #{inspect(errors)}}}"
    )

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
