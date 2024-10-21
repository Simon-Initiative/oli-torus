defmodule Oli.UserIdentities.UserIdentity do
  use Ecto.Schema

  schema "user_identities" do
    # MER-3835 TODO

    timestamps(type: :utc_datetime)
  end
end
