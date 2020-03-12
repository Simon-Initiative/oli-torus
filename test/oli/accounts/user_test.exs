defmodule Oli.Accounts.UserTest do
  use Oli.DataCase

  describe "user" do
    alias Oli.Accounts.User

    test "changeset should be invalid if password and confirmation do not match" do
      changeset = User.changeset(%User{}, %{email: "test@test.com", first_name: "First", last_name: "Last", password: "foo", password_confirmation: "bar"})
      refute changeset.valid?
    end
  end

end