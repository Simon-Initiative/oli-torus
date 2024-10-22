defmodule Oli.UserIdentities.UserIdentity do
  use Ecto.Schema

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
    |> Changeset.cast(attrs, [:provider, :uid, :user_id])
    |> Changeset.validate_required([:provider, :uid])
    |> Changeset.assoc_constraint(:user)
    |> Changeset.unique_constraint(:uid_provider, name: :user_identities_uid_provider_index)
  end
end
