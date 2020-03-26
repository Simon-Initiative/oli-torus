defmodule Oli.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activities" do
    field :slug, :string
    belongs_to :project, Oli.Course.Project
    timestamps()
  end

  @doc false
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:slug, :project_id])
    |> validate_required([:slug, :project_id])
    |> unique_constraint(:slug)
  end
end
