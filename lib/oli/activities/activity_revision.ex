defmodule Oli.Activities.ActivityRevision do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Phoenix.Param, key: :slug}
  schema "activity_revisions" do
    field :content, :map
    field :deleted, :boolean, default: false
    field :slug, :string
    field :objectives, {:array, :map}

    belongs_to :author, Oli.Accounts.Author
    belongs_to :activity, Oli.Activities.Activity
    belongs_to :previous_revision, Oli.Activities.ActivityRevision
    belongs_to :activity_type, Oli.Activities.Registration

    timestamps()
  end

  @doc false
  def changeset(activity_revision, attrs) do
    activity_revision
    |> cast(attrs, [:content, :slug, :deleted, :objectives, :author_id, :activity_id, :previous_revision_id, :activity_id])
    |> validate_required([:content, :slug, :deleted, :objectives,  :author_id, :activity_id, :activity_id])
    |> unique_constraint(:slug)
  end
end
