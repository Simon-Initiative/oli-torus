defmodule Oli.Authoring.RevisionBlob do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revision_blobs" do
    timestamps()
    field :json, :string
    belongs_to :revision, Oli.Authoring.Revision
  end

  @doc false
  def changeset(author, attrs \\ %{}) do
    author
    |> cast(attrs, [
      :revision,
      :json
    ])
    |> validate_required([:json, :revision])
  end
end
