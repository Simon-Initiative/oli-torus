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

      assert {:error, %Ecto.Changeset{}} =
               Groups.create_community(%{name: "Testing"})
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
