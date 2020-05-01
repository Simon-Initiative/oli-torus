defmodule Oli.Delivery.Page.ActivityContextTest do

  use Oli.DataCase

  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Activities

  describe "activity context" do

    setup do
      map = Seeder.base_project_with_resource2()

      %{revision: a1} = Seeder.create_activity(%{ content: %{ "stem" => "1", "authoring" => "a"}}, map.publication, map.project, map.author)
      %{revision: a2} = Seeder.create_activity(%{ content: %{ "stem" => "2"}}, map.publication, map.project, map.author)
      %{revision: a3} = Seeder.create_activity(%{ content: %{ "stem" => "3"}}, map.publication, map.project, map.author)

      Map.put(map, :a1, a1)
      |> Map.put(:a2, a2)
      |> Map.put(:a3, a3)
    end

    test "create_context_map/2 returns the activities mapped correctly", %{a1: a1, a2: a2, a3: a3} do

      registrations = Activities.list_activity_registrations()
      resource_ids = [a1.resource_id, a2.resource_id, a3.resource_id]

      revisions = Map.put(%{}, a1.resource_id, a1)
      |> Map.put(a2.resource_id, a2)
      |> Map.put(a3.resource_id, a3)

      m = ActivityContext.create_context_map(resource_ids, revisions, registrations)

      assert length(Map.keys(m)) == 3
      assert Map.get(m, a1.resource_id).slug == a1.slug
      assert Map.get(m, a1.resource_id).model == "{&quot;stem&quot;:&quot;1&quot;}"
      assert Map.get(m, a1.resource_id).state == "{&quot;active&quot;:true}"
      assert Map.get(m, a1.resource_id).delivery_element == "oli-multiple-choice-delivery"
      assert Map.get(m, a1.resource_id).script == "oli_multiple_choice_delivery.js"
      assert Map.get(m, a2.resource_id).slug == a2.slug
      assert Map.get(m, a3.resource_id).slug == a3.slug

    end

  end


end
