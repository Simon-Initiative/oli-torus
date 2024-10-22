defmodule Oli.UserIdentities.AuthorIdentity do
  use Ecto.Schema

  schema "author_identities" do
    # MER-3835 TODO
    field :provider, :string
    field :uid, :string

    belongs_to :user, Oli.Accounts.Author

    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates an author identity.
  """
  def changeset(author_identity_or_changeset, attrs) do
    author_identity_or_changeset
    |> Changeset.cast(attrs, [:provider, :uid, :user_id])
    |> Changeset.validate_required([:provider, :uid])
    |> Changeset.assoc_constraint(:user)
    |> Changeset.unique_constraint(:uid_provider, name: :author_identities_uid_provider_index)
  end
end
