defmodule Oli.Delivery.Gating.Strategies.Schedule do
  @moduledoc """
  Schedule strategy provides a temporal based gating condition. A schedule condition
  can define a start and/or end datetime for a resource to be available.
  """
  alias Oli.Delivery.Gating.GatingCondition
  alias Oli.Delivery.Gating.GatingConditionData

  @behaviour Oli.Delivery.Gating.Strategies.Strategy

  def type do
    :schedule
  end

  def check(%GatingCondition{data: %GatingConditionData{start_datetime: start_datetime, end_datetime: end_datetime}}) do
    now = DateTime.utc_now()

    case {start_datetime, end_datetime} do
      {nil, nil} ->
        true

      {start_datetime, nil} ->
        DateTime.compare(start_datetime, now) == :lt

      {nil, end_datetime} ->
        DateTime.compare(now, end_datetime) == :lt

      {start_datetime, end_datetime} ->
        DateTime.compare(start_datetime, now) == :lt and
        DateTime.compare(now, end_datetime) == :lt
    end
  end
end
