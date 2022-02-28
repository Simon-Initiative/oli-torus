defmodule Oli.Delivery.Gating.GatingConditionData do
  @moduledoc """
  GatingConditionData represents any condition related data which may be
  used by a particular strategy
  """
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Utils

  @primary_key false
  embedded_schema do
    # schedule strategy data
    field :start_datetime, :utc_datetime
    field :end_datetime, :utc_datetime
  end

  @doc false
  def changeset(gating_condition_data, attrs) do
    gating_condition_data
    |> cast(attrs, [
      :start_datetime,
      :end_datetime
    ])
    |> validate_dates_consistency(:start_datetime, :end_datetime)
  end
end
