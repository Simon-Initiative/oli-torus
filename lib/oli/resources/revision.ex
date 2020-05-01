defmodule Oli.Resources.Revision do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  schema "revisions" do

    # fields that apply to all types
    field :title, :string
    field :slug, :string
    field :deleted, :boolean, default: false
    belongs_to :author, Oli.Accounts.Author
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :previous_revision, Oli.Resources.Revision
    belongs_to :resource_type, Oli.Resources.ResourceType

    # fields that apply to only a subset of the types
    field :content, :map, default: %{}
    field :children, {:array, :id}, default: []
    field :objectives, :map, default: %{}
    field :graded, :boolean, default: false
    belongs_to :activity_type, Oli.Activities.Registration

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(resource_revision, attrs \\ %{}) do
    resource_revision
    |> cast(attrs, [:title, :slug, :deleted, :author_id, :resource_id, :previous_revision_id, :resource_type_id, :content, :children, :objectives, :graded, :activity_type_id])
    |> validate_required([:title, :deleted, :author_id, :resource_id, :resource_type_id])
    |> Slug.update_on_change("revisions")
  end

end
