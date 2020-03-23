defmodule Oli.Publishing.ActivityMapping do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_mappings" do

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :activity, Oli.Activities.Activity
    belongs_to :revision, Oli.Activities.ActivityRevision

    timestamps()
  end

  @doc false
  def changeset(activity_mapping, attrs) do
    activity_mapping
    |> cast(attrs, [])
    |> validate_required([:publication, :activity, :revision])
  end
end
