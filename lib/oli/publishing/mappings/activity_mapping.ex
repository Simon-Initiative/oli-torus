defmodule Oli.Publishing.ActivityMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_mappings" do

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :activity, Oli.Authoring.Activities.Activity
    belongs_to :revision, Oli.Authoring.Activities.ActivityRevision

    timestamps()
  end

  @doc false
  def changeset(activity_mapping, attrs) do
    activity_mapping
    |> cast(attrs, [:publication_id, :activity_id, :revision_id])
    |> validate_required([:publication_id, :activity_id, :revision_id])
  end
end
