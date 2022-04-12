defmodule Oli.Publishing.PublisherTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Publishing.Publisher
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

    test "changeset should be invalid if name is not unique" do
      publisher = insert(:publisher)

      assert {:error, changeset} =
               build(:publisher, %{name: publisher.name})
               |> Publisher.changeset()
               |> Repo.insert()

      assert length(changeset.errors) == 1
      assert changeset.errors[:name] |> elem(0) == "has already been taken"
    end
  end
end
