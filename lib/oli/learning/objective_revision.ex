defmodule Oli.Learning.ObjectiveRevision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objective_revisions" do
    field :title, :string
    field :children, {:array, :id}
    field :deleted, :boolean, default: false

    belongs_to :objective, Oli.Learning.Objective
    belongs_to :previous_revision, Oli.Learning.ObjectiveRevision

    timestamps()
  end

  @doc false
  def changeset(objective_revision, attrs) do
    objective_revision
    |> cast(attrs, [:title, :children, :deleted, :objective_id, :previous_revision_id])
    |> validate_required([:title, :children, :deleted, :objective_id])
  end
end
