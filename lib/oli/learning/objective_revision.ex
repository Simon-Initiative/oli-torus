defmodule Oli.Learning.ObjectiveRevision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objective_revisions" do
    field :title, :string
    field :children, :map

    belongs_to :objective, Oli.Learning.Objective
    belongs_to :previous_revision, Oli.Learning.ObjectiveRevision

    timestamps()
  end

  @doc false
  def changeset(objective_revision, attrs) do
    objective_revision
    |> cast(attrs, [:title, :children])
    |> validate_required([:title, :children, :objective, :previous_revision])
  end
end
