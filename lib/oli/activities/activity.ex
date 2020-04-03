defmodule Oli.Activities.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activities" do
    belongs_to :family, Oli.Activities.ActivityFamily
    belongs_to :project, Oli.Course.Project
    timestamps()
  end

  @doc false
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:family_id, :project_id])
    |> validate_required([:family_id, :project_id])
  end
end
