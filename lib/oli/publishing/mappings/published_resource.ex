defmodule Oli.Publishing.PublishedResource do
  use Ecto.Schema
  import Ecto.Changeset

  schema "published_resources" do

    field :lock_updated_at, :naive_datetime

    belongs_to :publication, Oli.Publishing.Publication
    belongs_to :resource, Oli.Resources.Resource
    belongs_to :revision, Oli.Resources.Revision
    belongs_to :author, Oli.Accounts.Author, foreign_key: :locked_by_id

    timestamps()
  end

  @doc false
  def changeset(mapping, attrs) do
    mapping
    |> cast(attrs, [:publication_id, :resource_id, :revision_id, :locked_by_id, :lock_updated_at])
    |> validate_required([:publication_id, :resource_id, :revision_id])
  end
end
