defmodule Oli.Authoring.Learning.ObjectiveRevision do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  schema "objective_revisions" do
    field :title, :string
    field :slug, :string
    field :children, {:array, :id}
    field :deleted, :boolean, default: false

    belongs_to :objective, Oli.Authoring.Learning.Objective
    belongs_to :previous_revision, Oli.Authoring.Learning.ObjectiveRevision

    timestamps()
  end

  @doc false
  def changeset(objective_revision, attrs \\ %{}) do
    objective_revision
    |> cast(attrs, [:title, :slug, :children, :deleted, :objective_id, :previous_revision_id])
    |> validate_required([:title, :children, :deleted, :objective_id])
    |> Slug.maybe_update_slug("objective_revisions")
  end
end
