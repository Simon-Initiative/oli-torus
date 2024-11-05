defmodule Oli.UserIdentities.UserIdentity do
  use Ecto.Schema

  import Ecto.Changeset

  schema "user_identities" do
    # MER-3835 TODO
    field :provider, :string
    field :uid, :string

    belongs_to :user, Oli.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates a user identity.
  """
  def changeset(user_identity_or_changeset, attrs) do
    user_identity_or_changeset
    |> cast(attrs, [:provider, :uid, :user_id])
    |> validate_required([:provider, :uid])
    |> assoc_constraint(:user)
    |> unique_constraint(:uid_provider, name: :user_identities_uid_provider_index)
  end
end
