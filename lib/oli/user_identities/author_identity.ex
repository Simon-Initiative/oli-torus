defmodule Oli.UserIdentities.AuthorIdentity do
  use Ecto.Schema

  schema "author_identities" do
    # MER-3835 TODO

    timestamps(type: :utc_datetime)
  end
end
