defmodule Oli.UserIdentities.UserIdentity do
  use Ecto.Schema
  use PowAssent.Ecto.UserIdentities.Schema, user: Oli.Accounts.User

  schema "user_identities" do
    pow_assent_user_identity_fields()

    timestamps(type: :utc_datetime)
  end
end
