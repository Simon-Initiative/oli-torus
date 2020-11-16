defmodule Oli.Accounts.AuthorTest do
  use Oli.DataCase

  describe "author" do
    alias Oli.Accounts.Author

    test "changeset should be invalid if password and confirmation do not match" do
      changeset = Author.changeset(%Author{}, %{email: "test@test.com", given_name: "First", family_name: "Last", password: "foo", password_confirmation: "bar"})
      refute changeset.valid?
    end
  end

end
