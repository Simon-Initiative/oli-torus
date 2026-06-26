defmodule Oli.Experiments.Schemas.DecisionPoint do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Experiments.Schemas.ExperimentDefinition
  alias Oli.Resources.{Resource, Revision}

  schema "experiment_decision_points" do
    field :decision_point_key, :string
    field :title, :string
    field :position, :integer, default: 0

    belongs_to :experiment, ExperimentDefinition
    belongs_to :alternatives_resource, Resource
    belongs_to :alternatives_revision, Revision

    timestamps(type: :utc_datetime)
  end

  def changeset(decision_point, attrs \\ %{}) do
    decision_point
    |> cast(attrs, [
      :experiment_id,
      :alternatives_resource_id,
      :alternatives_revision_id,
      :decision_point_key,
      :title,
      :position
    ])
    |> validate_required([
      :experiment_id,
      :alternatives_resource_id,
      :alternatives_revision_id,
      :decision_point_key,
      :position
    ])
    |> validate_length(:decision_point_key, min: 1, max: 255)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:experiment_id)
    |> foreign_key_constraint(:alternatives_resource_id)
    |> foreign_key_constraint(:alternatives_revision_id)
    |> unique_constraint([:experiment_id, :decision_point_key])
  end
end
