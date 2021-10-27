defmodule Oli.GroupsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Groups

  describe "community" do
    alias Oli.Groups.Community

    test "create_community/1 with valid data creates a community" do
      params = params_for(:community)
      assert {:ok, %Community{} = community} = Groups.create_community(params)

      assert community.name == params.name
      assert community.description == params.description
      assert community.key_contact == params.key_contact
      assert community.global_access == params.global_access
    end

    test "create_community/1 with existing name returns error changeset" do
      insert(:community, %{name: "Testing"})

      assert {:error, %Ecto.Changeset{}} = Groups.create_community(%{name: "Testing"})
    end

    test "list_communities/0 returns ok when there are no communities" do
      assert [] = Groups.list_communities()
    end

    test "list_communities/0 returns all the communities" do
      insert_list(3, :community)

      assert 3 = length(Groups.list_communities())
    end

    test "get_community/1 returns a community when the id exists" do
      community = insert(:community)

      returned_community = Groups.get_community(community.id)

      assert community.id == returned_community.id
      assert community.name == returned_community.name
    end

    test "get_community/1 returns nil if the community does not exist" do
      assert nil == Groups.get_community(123)
    end

    test "update_community/2 updates the community successfully" do
      community = insert(:community)

      {:ok, updated_community} = Groups.update_community(community, %{name: "new_name"})

      assert community.id == updated_community.id
      assert updated_community.name == "new_name"
    end

    test "update_community/2 does not update the community when there is an invalid field" do
      community = insert(:community)
      another_community = insert(:community)

      {:error, changeset} = Groups.update_community(community, %{name: another_community.name})
      {error, _} = changeset.errors[:name]

      refute changeset.valid?
      assert error =~ "has already been taken"
    end

    test "delete_community/1 deletes the community" do
      community = insert(:community)
      assert {:ok, %Community{}} = Groups.delete_community(community)
      refute Groups.get_community(community.id)
    end

    test "change_community/1 returns a community changeset" do
      community = insert(:community)
      assert %Ecto.Changeset{} = Groups.change_community(community)
    end
  end
end
