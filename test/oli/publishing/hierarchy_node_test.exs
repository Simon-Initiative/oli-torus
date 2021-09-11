defmodule Oli.Publishing.DeliveryResolverTest do
  use Oli.DataCase

  alias Oli.Publishing.DeliveryResolver

  describe "hierarchy node" do
    setup do
      Seeder.base_project_with_resource4()
    end

    test "flatten_pages/1", %{} do
      throw("TODO")
    end

    test "find_in_hierarchy/2", %{} do
      throw("TODO")
    end
  end
end
