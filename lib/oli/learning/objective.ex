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
    |> cast(attrs, [:slug])
    |> validate_required([:slug, :project])
    |> unique_constraint(:slug)
  end
end
