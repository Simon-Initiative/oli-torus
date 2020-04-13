defmodule Oli.Authoring.Resources.ResourceRevision do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Utils.Slug

  schema "resource_revisions" do
    field :children, {:array, :string}, default: []
    field :content, {:array, :map}, default: []
    field :objectives, {:array, :string}, default: []
    field :deleted, :boolean, default: false
    field :slug, :string
    field :title, :string

    belongs_to :author, Oli.Accounts.Author
    belongs_to :resource, Oli.Authoring.Resources.Resource
    belongs_to :previous_revision, Oli.Authoring.Resources.ResourceRevision
    belongs_to :resource_type, Oli.Authoring.Resources.ResourceType

    timestamps()
  end

  @doc false
  def changeset(resource_revision, attrs \\ %{}) do
    resource_revision
    |> cast(attrs, [:title, :slug, :content, :children, :objectives, :deleted, :author_id, :resource_id, :previous_revision_id, :resource_type_id])
    |> validate_required([:title, :slug, :content, :objectives, :children, :deleted, :objectives, :author_id, :resource_id, :resource_type_id])
    |> Slug.maybe_update_slug("resource_revisions")
  end

end
