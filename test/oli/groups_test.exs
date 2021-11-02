defmodule Oli.GroupsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Groups

  describe "community" do
    alias Oli.Groups.Community

    test "create_community/1 with valid data creates a community" do
      assert {:ok, %Community{} = community} =
        Groups.create_community(%{
          name: "Testing name",
          description: "Testing description",
          key_contact: "Testing key contact",
          prohibit_global_access: false})

      assert community.name == "Testing name"
      assert community.description == "Testing description"
      assert community.key_contact == "Testing key contact"
      assert community.prohibit_global_access == false
    end

    test "create_community/1 with existing name returns error changeset" do
      insert(:community, %{name: "Testing"})

      assert {:error, %Ecto.Changeset{}}
        = Groups.create_community(%{name: "Testing"})
    end

    test "list_communities/0 returns ok when there are no communities" do
      assert [] = Groups.list_communities()
    end

    test "list_communities/0 returns all the communities" do
      insert_list(3, :community)

      assert 3 = length(Groups.list_communities())
    end
  end
end
