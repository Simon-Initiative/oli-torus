defmodule Oli.Activities.ActivityRevision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_revisions" do
    field :content, :string
    field :deleted, :boolean, default: false
    field :slug, :string

    belongs_to :author, Oli.Accounts.Author
    belongs_to :activity, Oli.Activities.Activity
    belongs_to :previous_revision, Oli.Activities.ActivityRevision
    belongs_to :activity_type, Oli.Activities.Registration

    timestamps()
  end

  @doc false
  def changeset(activity_revision, attrs) do
    activity_revision
    |> cast(attrs, [:content, :slug, :deleted])
    |> validate_required([:content, :slug, :deleted, :author, :activity, :previous_revision, :activity_type])
    |> unique_constraint(:slug)
  end
end
