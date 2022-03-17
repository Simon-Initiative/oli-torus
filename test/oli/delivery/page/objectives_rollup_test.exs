defmodule Oli.Delivery.Page.ObjectivesRollupTest do
  use Oli.DataCase
  alias Oli.Delivery.Page.ObjectivesRollup

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
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_objective("objective two", :o2)

      o = Map.get(map, :o1).revision.resource_id
      o2 = Map.get(map, :o2).revision.resource_id

      map =
        Seeder.add_activity(
          map,
          %{title: "one", objectives: %{"1" => [o]}, content: content},
          :a1
        )
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
        objectives: %{"attached" => []}
      }

      attrs2 = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [o2]}
      }

      attrs3 = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{}
      }

      Seeder.add_page(map, attrs, :p1)
      |> Seeder.add_page(attrs2, :p2)
      |> Seeder.add_page(attrs3, :p3)

    end

    test "rolls up correctly when directly attached to page",
         %{
           project: project,
           p1: p1,
           p2: p2,
           p3: p3,
           a1: a1,
           a2: a2
         } do
      activity_revisions = [a1.revision, a2.revision]

      # Test that when none are attached
      assert [] == ObjectivesRollup.rollup_objectives(
        p1.revision, activity_revisions, Oli.Publishing.AuthoringResolver, project.slug)

      # Tests when one is attached
      assert ["objective two"] == ObjectivesRollup.rollup_objectives(
        p2.revision, activity_revisions, Oli.Publishing.AuthoringResolver, project.slug)

      # Tests when objectives map is malformed (simply an empty map in this case)
      assert [] == ObjectivesRollup.rollup_objectives(
        p3.revision, activity_revisions, Oli.Publishing.AuthoringResolver, project.slug)

    end
  end
end
