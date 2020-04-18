defmodule Oli.Publishing.ObjectiveMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objective_mappings" do

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :objective, Oli.Authoring.Learning.Objective
    belongs_to :revision, Oli.Authoring.Learning.ObjectiveRevision

    timestamps()
  end

  @doc false
  def changeset(objective_mapping, attrs \\ %{}) do
    objective_mapping
    |> cast(attrs, [:publication_id, :objective_id, :revision_id])
    |> validate_required([:publication_id, :objective_id, :revision_id])
  end
end
