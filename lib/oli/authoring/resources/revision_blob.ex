defmodule Oli.Authoring.RevisionBlob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revision_blobs" do
    timestamps()
    field :content, :map
    belongs_to :revision, Oli.Authoring.Revision
  end

  @doc false
  def changeset(revision_blob, attrs \\ %{}) do
    revision_blob
    |> cast(attrs, [
      :revision,
      :content
    ])
    |> validate_required([:content, :revision])
  end
end
