defmodule Oli.Publishing.ObjectiveMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "objective_mappings" do

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :objective, Oli.Learning.Objective
    belongs_to :revision, Oli.Learning.ObjectiveRevision

    timestamps()
  end

  @doc false
  def changeset(objective_mapping, attrs) do
    objective_mapping
    |> cast(attrs, [])
    |> validate_required([:publication, :objective, :revision])
  end
end
