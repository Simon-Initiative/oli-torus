defmodule Oli.InventoriesTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Inventories
  alias Oli.Inventories.Publisher

  describe "publishers" do
    test "create_publisher/1 with valid data creates a publisher" do
      params = params_for(:publisher)
      assert {:ok, %Publisher{} = publisher} = Inventories.create_publisher(params)

      assert publisher.name == params.name
      assert publisher.email == params.email
      assert publisher.address == params.address
      assert publisher.main_contact == params.main_contact
      assert publisher.website_url == params.website_url
    end

    test "create_publisher/1 with existing name returns error changeset" do
      publisher = insert(:publisher)

      assert {:error, %Ecto.Changeset{}} = Inventories.create_publisher(%{name: publisher.name})
    end

    test "list_publishers/0 returns ok when there are no publishers" do
      assert [] = Inventories.list_publishers()
    end

    test "list_publishers/0 returns all the publishers" do
      insert_list(3, :publisher)

      assert 3 = length(Inventories.list_publishers())
    end

    test "get_publisher/1 returns a publisher when the id exists" do
      publisher = insert(:publisher)

      returned_publisher = Inventories.get_publisher(publisher.id)

      assert publisher.id == returned_publisher.id
      assert publisher.name == returned_publisher.name
    end

    test "get_publisher/1 returns nil if the publisher does not exist" do
      assert nil == Inventories.get_publisher(123)
    end

    test "update_publisher/2 updates the publisher successfully" do
      publisher = insert(:publisher)

      {:ok, updated_publisher} = Inventories.update_publisher(publisher, %{name: "new_name"})

      assert publisher.id == updated_publisher.id
      assert updated_publisher.name == "new_name"
    end

    test "update_publisher/2 does not update the publisher when there is an invalid field" do
      publisher = insert(:publisher)
      another_publisher = insert(:publisher)

      {:error, changeset} =
        Inventories.update_publisher(publisher, %{name: another_publisher.name})

      {error, _} = changeset.errors[:name]

      refute changeset.valid?
      assert error =~ "has already been taken"
    end

    test "delete_publisher/1 deletes the publisher" do
      publisher = insert(:publisher)
      assert {:ok, deleted_publisher} = Inventories.delete_publisher(publisher)
      refute Inventories.get_publisher(deleted_publisher.id)
    end

    test "change_publisher/1 returns a publisher changeset" do
      publisher = insert(:publisher)
      assert %Ecto.Changeset{} = Inventories.change_publisher(publisher)
    end
  end
end
