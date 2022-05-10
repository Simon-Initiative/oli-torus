defmodule Oli.Inventories.PublisherTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Inventories.Publisher
  alias Oli.Repo

  describe "changeset/2" do
    test "changeset should be valid with correct attributes" do
      changeset = Publisher.changeset(build(:publisher))

      assert changeset.valid?
    end

    test "changeset should be invalid if name is empty" do
      changeset = Publisher.changeset(build(:publisher, %{name: ""}))

      refute changeset.valid?
    end

    test "changeset should be invalid if email is empty" do
      changeset = Publisher.changeset(build(:publisher, %{email: ""}))

      refute changeset.valid?
    end

    test "changeset should be invalid if email has invalid format" do
      changeset = Publisher.changeset(build(:publisher), %{email: "invalid_email"})

      refute changeset.valid?
      assert changeset.errors[:email] |> elem(0) == "has invalid format"
    end

    test "changeset should be invalid if name is not unique" do
      publisher = insert(:publisher)

      assert {:error, changeset} =
               build(:publisher, %{name: publisher.name})
               |> Publisher.changeset()
               |> Repo.insert()

      assert length(changeset.errors) == 1
      assert changeset.errors[:name] |> elem(0) == "has already been taken"
    end

    test "changeset should be invalid if default true is not unique" do
      assert {:error, changeset} =
               build(:publisher, %{default: true})
               |> Publisher.changeset()
               |> Repo.insert()

      assert length(changeset.errors) == 1
      assert changeset.errors[:default] |> elem(0) == "there must only be one default"
    end
  end
end
