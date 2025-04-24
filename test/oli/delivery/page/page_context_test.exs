defmodule Oli.Delivery.Page.PageContextTest do
  use Oli.DataCase

  alias Oli.Delivery.Page.PageContext
  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Delivery.Sections

  describe "page context" do
    setup do
      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "1",
              "responses" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            }
          ]
        }
      }

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)

      o = Map.get(map, :o1).revision.resource_id

      map =
        Seeder.add_activity(
          map,
          %{title: "one", objectives: %{"1" => [o]}, content: content},
          :a1
        )
        |> Seeder.add_activity(%{title: "two", content: %{"stem" => "3", "authoring" => %{"parts" => [%{"id" => "1", "responses" => []}]}}}, :a2)
        |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [o]}
      }

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(map, attrs, :p1)
      |> Seeder.create_section_resources()
    end

    test "create_context/2 returns the activities mapped correctly",
         %{
           section: section,
           p1: p1,
           a1: a1,
           user1: user,
           container: %{resource: container_resource, revision: container_revision}
         } = map do
      page1 = Map.get(map, :page1)
      page2 = Map.get(map, :page2)
      publication = Map.get(map, :publication)

      Seeder.replace_pages_with(
        [page1, %{id: p1.resource.id}, page2],
        container_resource,
        container_revision,
        publication
      )

      Seeder.rebuild_section_resources(%{section: section, publication: publication})

      datashop_session_id = UUID.uuid4()

      Sections.enroll(user.id, section.id, [ContextRoles.get_role(:context_learner)])

      context = PageContext.create_for_visit(section, p1.revision.slug, user, datashop_session_id)

      # verify activities map
      assert Map.get(context.activities, a1.resource.id).model != nil

      # verify objectives map
      assert context.objectives == ["objective one"]
      refute context.collab_space_config
    end
  end
end
