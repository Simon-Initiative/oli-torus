defmodule Oli.Analytics.XAPI.Utils do

  def record_pipeline_stats(stats) do
    :telemetry.execute([:oli, :xapi, :pipeline], stats)
  end

end
