defmodule Oli.Resources.ResourceRevision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_revisions" do
    field :children, {:array, :id}, default: []
    field :content, {:array, :map}, default: []
    field :objectives, {:array, :id}, default: []
    field :deleted, :boolean, default: false
    field :slug, :string
    field :title, :string

    belongs_to :author, Oli.Accounts.Author
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :previous_revision, Oli.Resources.ResourceRevision
    belongs_to :resource_type, Oli.Resources.ResourceType

    timestamps()
  end

  @doc false
  def changeset(resource_revision, attrs \\ %{}) do
    resource_revision
    |> cast(attrs, [:title, :slug, :content, :children, :objectives, :deleted, :author_id, :resource_id, :previous_revision_id, :resource_type_id])
    |> validate_required([:title, :slug, :content, :objectives, :children, :deleted, :objectives, :author_id, :resource_id, :resource_type_id])
  end
end
