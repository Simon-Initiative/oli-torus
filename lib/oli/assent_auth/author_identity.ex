defmodule Oli.AssentAuth.AuthorIdentity do
  use Ecto.Schema

  import Ecto.Changeset

  schema "author_identities" do
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
    |> cast(attrs, [:provider, :uid, :user_id])
    |> validate_required([:provider, :uid])
    |> assoc_constraint(:user)
    |> unique_constraint(:uid_provider, name: :author_identities_uid_provider_index)
  end
end
