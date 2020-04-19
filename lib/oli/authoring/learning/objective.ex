defmodule Oli.Authoring.Learning.Objective do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objectives" do
    belongs_to :family, Oli.Authoring.Learning.ObjectiveFamily
    belongs_to :project, Oli.Authoring.Course.Project
    timestamps()
  end

  @doc false
  def changeset(objective, attrs \\ %{}) do
    objective
    |> cast(attrs, [:family_id, :project_id])
    |> validate_required([:family_id, :project_id])
  end
end
