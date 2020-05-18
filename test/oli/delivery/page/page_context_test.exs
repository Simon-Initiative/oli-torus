defmodule Oli.Delivery.Page.PageContextTest do

  use Oli.DataCase

  alias Oli.Delivery.Page.PageContext

  describe "page context" do

    setup do
      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: %{"authoring" => "3"}}, :a1)
      |> Seeder.add_activity(%{title: "two", content: %{"stem" => "3"}}, :a2)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.add_page(map, attrs, :p1)

    end

    test "create_context/2 returns the activities mapped correctly", %{section: section, p1: p1, a1: a1, user1: user, container: %{resource: container_resource, revision: container_revision }} = map do

      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)
      publication = Map.get(map, :publication)

      Seeder.attach_pages_to([page1, %{id: p1.resource.id}, page2], container_resource, container_revision, publication)

      context = PageContext.create_page_context(section.context_id, p1.revision.slug, user.id)

      # verify activities map
      assert Map.get(context.activities, a1.resource.id).model == "{}"

      # verify objectives map
      assert context.objectives == ["objective one"]

      # verify previous and next are correct
      assert context.previous_page.resource_id == page1.id
      assert context.next_page.resource_id == page2.id

      # verify all other possible variants of prev and next:

      Seeder.attach_pages_to([p1.resource, page2], container_resource, container_revision, publication)
      context = PageContext.create_page_context(section.context_id, p1.revision.slug, user.id)
      assert context.previous_page == nil
      assert context.next_page.resource_id == page2.id

      Seeder.attach_pages_to([page2, p1.resource], container_resource, container_revision, publication)
      context = PageContext.create_page_context(section.context_id, p1.revision.slug, user.id)
      assert context.previous_page.resource_id == page2.id
      assert context.next_page == nil

      Seeder.attach_pages_to([p1.resource], container_resource, container_revision, publication)
      context = PageContext.create_page_context(section.context_id, p1.revision.slug, user.id)
      assert context.previous_page == nil
      assert context.next_page == nil

    end

  end


end
