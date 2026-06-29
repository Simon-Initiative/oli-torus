defmodule Oli.Experiments.Schemas.Condition do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{DecisionPoint, ExperimentDefinition}

  schema "experiment_conditions" do
    field :condition_code, :string
    field :option_id, :string
    field :label, :string
    field :weight, :float, default: 1.0
    field :active, :boolean, default: true
    field :position, :integer, default: 0

    belongs_to :experiment, ExperimentDefinition
    belongs_to :decision_point, DecisionPoint

    timestamps(type: :utc_datetime)
  end

  def changeset(condition, attrs \\ %{}) do
    condition
    |> cast(attrs, [
      :experiment_id,
      :decision_point_id,
      :condition_code,
      :option_id,
      :label,
      :weight,
      :active,
      :position
    ])
    |> validate_required([
      :experiment_id,
      :decision_point_id,
      :condition_code,
      :weight,
      :active,
      :position
    ])
    |> validate_length(:condition_code, min: 1, max: 255)
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:decision_point_id)
    |> unique_constraint([:decision_point_id, :condition_code],
      name: :experiment_conditions_code_idx
    )
  end
end
