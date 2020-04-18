defmodule Oli.Authoring.Activities.ActivityRevision do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug
  alias Oli.Repo

  @derive {Phoenix.Param, key: :slug}
  schema "activity_revisions" do
    field :content, :map
    field :deleted, :boolean, default: false
    field :slug, :string
    field :title, :string
    field :objectives, {:array, :map}

    belongs_to :author, Oli.Accounts.Author
    belongs_to :activity, Oli.Authoring.Activities.Activity
    belongs_to :previous_revision, Oli.Authoring.Activities.ActivityRevision
    belongs_to :activity_type, Oli.Authoring.Activities.Registration

    timestamps()
  end

  @doc false
  def changeset(activity_revision, attrs) do
    activity_revision
    |> cast(attrs, [:content, :slug, :title, :deleted, :objectives, :author_id, :activity_id, :previous_revision_id, :activity_type_id])
    |> validate_required([:content, :deleted, :objectives,  :author_id, :activity_id, :activity_type_id])
    |> title_from_registration()
    |> Slug.maybe_update_slug("activity_revisions")
  end


  # if the title is not present in the changeset, use the title of the
  # activity registration
  def title_from_registration(changeset) do
    if changeset.valid? and Ecto.Changeset.get_change(changeset, :title) == nil do
      case Repo.get(Oli.Authoring.Activities.Registration, Ecto.Changeset.get_field(changeset, :activity_type_id)) do
        %{title: title} -> Ecto.Changeset.put_change(changeset, :title, title)
        _ -> changeset
      end
    else
      changeset
    end
  end
end
