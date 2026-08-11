defmodule Oli.Experiments.Schemas.DecisionPointCondition do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Experiments.Schemas.{Condition, DecisionPoint}

  schema "experiment_decision_point_conditions" do
    field :option_id, :string
    field :weight, :float, default: 1.0
    field :position, :integer, default: 0
    belongs_to :decision_point, DecisionPoint
    belongs_to :condition, Condition
    timestamps(type: :utc_datetime)
  end

  @doc false
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(mapping, attrs \\ %{}) do
    mapping
    |> cast(attrs, [:decision_point_id, :condition_id, :option_id, :weight, :position])
    |> validate_required([:decision_point_id, :condition_id, :option_id, :weight, :position])
    |> validate_length(:option_id, min: 1, max: 255)
    |> validate_number(:weight, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:decision_point_id)
    |> foreign_key_constraint(:condition_id)
    |> unique_constraint([:decision_point_id, :condition_id],
      name: :experiment_decision_point_conditions_condition_idx
    )
    |> unique_constraint([:decision_point_id, :option_id],
      name: :experiment_decision_point_conditions_option_idx
    )
  end
end
