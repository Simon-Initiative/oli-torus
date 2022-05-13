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

    test "create_publisher/1 with invalid email returns error changeset" do
      publisher_attrs = params_for(:publisher, %{email: "invalid_email"})

      assert {:error, %Ecto.Changeset{}} = Inventories.create_publisher(publisher_attrs)
    end

    test "find_or_create_publisher/1 with valid data creates a publisher" do
      params = params_for(:publisher)
      assert {:ok, %Publisher{} = publisher} = Inventories.find_or_create_publisher(params)

      assert publisher.name == params.name
      assert publisher.email == params.email
      assert publisher.address == params.address
      assert publisher.main_contact == params.main_contact
      assert publisher.website_url == params.website_url
    end

    test "find_or_create_publisher/1 returns existing publisher" do
      publisher = insert(:publisher)

      assert {:ok, %Publisher{} = returned_publisher} =
               Inventories.find_or_create_publisher(%{name: publisher.name})

      assert publisher == returned_publisher
    end

    test "find_or_create_publisher/1 with invalid_data returns error changeset" do
      params = Map.delete(params_for(:publisher), :email)

      assert {:error, %Ecto.Changeset{}} = Inventories.find_or_create_publisher(params)
    end

    test "list_publishers/0 returns all the publishers" do
      insert_list(3, :publisher)

      # There is an existing default publisher
      assert length(Inventories.list_publishers()) == 4
    end

    test "get_publisher/1 returns a publisher when the id exists" do
      publisher = insert(:publisher)

      returned_publisher = Inventories.get_publisher(publisher.id)

      assert publisher.id == returned_publisher.id
      assert publisher.name == returned_publisher.name
    end

    test "get_publisher/1 returns nil if the publisher does not exist" do
      refute Inventories.get_publisher(123)
    end

    test "get_publisher_by/1 returns a publisher if it exists" do
      publisher = insert(:publisher)

      returned_publisher = Inventories.get_publisher_by(%{name: publisher.name})

      assert publisher == returned_publisher
    end

    test "get_publisher_by/1 returns nil if the publisher does not exist" do
      refute Inventories.get_publisher_by(%{name: "invalid"})
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

    test "delete_publisher/1 returns an error when the publisher has associated projects" do
      project = insert(:project)
      assert {:error, changeset} = Inventories.delete_publisher(project.publisher)
      assert changeset.errors[:projects] |> elem(0) == "are still associated with this entry"
    end

    test "delete_publisher/1 returns an error when the publisher has associated products" do
      section = insert(:section)
      assert {:error, changeset} = Inventories.delete_publisher(section.publisher)
      assert changeset.errors[:products] |> elem(0) == "are still associated with this entry"
    end

    test "delete_publisher/1 returns an error when trying to delete the default publisher" do
      default_publisher = Inventories.default_publisher()
      assert {:error, changeset} = Inventories.delete_publisher(default_publisher)
      assert changeset.errors[:default] |> elem(0) == "cannot delete the default publisher"
    end

    test "change_publisher/1 returns a publisher changeset" do
      publisher = insert(:publisher)
      assert %Ecto.Changeset{} = Inventories.change_publisher(publisher)
    end

    test "default_publisher/0 returns the default publisher" do
      assert Inventories.default_publisher().default
    end

    test "set_default_publisher/1 unsets the current one and sets the new one" do
      publisher = insert(:publisher)
      old_default = Inventories.default_publisher()

      assert old_default.default
      refute publisher.default

      assert {:ok, new_default} = Inventories.set_default_publisher(publisher)

      assert new_default.id == publisher.id
      assert new_default.default
      refute Inventories.get_publisher(old_default.id).default
    end
  end
end
