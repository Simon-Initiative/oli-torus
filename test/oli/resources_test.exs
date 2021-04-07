defmodule Oli.Resources.ResourcesTest do
  use Oli.DataCase

  alias Oli.Resources

  describe "resources" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "list_resources/0 returns all resources", _ do
      assert length(Resources.list_resources()) == 3
    end

    test "get_resource!/1 returns the resource with given id", %{
      container: %{resource: container_resource}
    } do
      assert Resources.get_resource!(container_resource.id) == container_resource
    end
  end
end
