defmodule Oli.Learning.Objective do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objectives" do
    field :slug, :string
    belongs_to :project, Oli.Course.Project
    timestamps()
  end

  @doc false
  def changeset(objective, attrs) do
    objective
    |> cast(attrs, [:slug, :project_id])
    |> validate_required([:slug, :project_id])
    |> unique_constraint(:slug)
  end
end
