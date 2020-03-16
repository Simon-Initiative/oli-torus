defmodule Oli.Authoring.ObjectiveObjective do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "objectives_objectives" do
    timestamps()
    belongs_to :parent, Oli.Authoring.Objective
    belongs_to :child, Oli.Authoring.Objective
  end

  @doc false
  def changeset(objective_objective, attrs) do
    objective_objective
    |> cast(attrs, [:user_id, :project_id, :project_role_id])
    |> validate_required([:user_id, :project_id, :project_role_id])
  end
end
