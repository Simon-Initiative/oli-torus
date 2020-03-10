defmodule Oli.Authoring.Revision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "revisions" do
    timestamps()
    field :type, :string
    field :md5, :string
    field :revision_number, :integer
    belongs_to :author, Oli.Accounts.User
    belongs_to :previous_revision, Oli.Authoring.Revision
    has_one :revision_blob, Oli.Authoring.RevisionBlob
    has_one :resource, Oli.Authoring.Resource, foreign_key: :last_revision_id
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :type,
      :md5,
      :revision_number,
      :author,
      :previous_revision
    ])
    |> validate_required([:type, :md5, :revision_number, :author])
    |> unique_constraint(:md5)
  end
end
