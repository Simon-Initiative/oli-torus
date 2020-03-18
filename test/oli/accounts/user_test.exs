defmodule Oli.Accounts.AuthroTest do
  use Oli.DataCase

  describe "author" do
    alias Oli.Accounts.Authro

    test "changeset should be invalid if password and confirmation do not match" do
      changeset = Authro.changeset(%Authro{}, %{email: "test@test.com", first_name: "First", last_name: "Last", password: "foo", password_confirmation: "bar"})
      refute changeset.valid?
    end
  end

end
