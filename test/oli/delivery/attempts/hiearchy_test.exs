defmodule Oli.Delivery.Attempts.PageLifecycle.HierarchyTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.PageLifecycle.{Hierarchy, VisitContext, AttemptState}

  describe "creating the attempt tree records" do
    setup do
      content1 = %{
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

      content2 = %{
        "stem" => "2",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "some_key",
              "responses" => [],
              "scoringStrategy" => "best",
              "evaluationStrategy" => "regex"
            },
            %{
              "id" => "some_other_key",
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
        |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
        |> Seeder.add_activity(%{title: "two", content: content2}, :a2)
        |> Seeder.add_activity(%{title: "three", content: content1, scope: :banked}, :a3)
        |> Seeder.add_activity(%{title: "three", content: content1, scope: :banked}, :a3)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a1).resource.id},
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a2).resource.id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
        graded: true
      }

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(map, attrs, :p1)
      |> Seeder.create_section_resources()
    end

    test "create the attempt tree", %{
      p1: p1,
      user1: user,
      section: section,
      a1: a1,
      a2: a2,
      publication: pub
    } do
      Attempts.track_access(p1.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/7
      datashop_session_id = UUID.uuid4()

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user: user,
          audience_role: :student,
          activity_provider: activity_provider,
          blacklisted_activities: [],
          publication_id: pub.id,
          effective_settings:
            Oli.Delivery.Settings.get_combined_settings(p1.revision, section.id, user.id)
        })

      assert resource_attempt.lifecycle_state == :active

      # verify that creating the attempt tree returns both activity attempts
      {:ok, %AttemptState{resource_attempt: resource_attempt, attempt_hierarchy: attempts}} =
        AttemptState.fetch_attempt_state(resource_attempt, p1.revision)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      # verify that reading the latest attempts back from the db gives us
      # the same results
      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      {act_attempt1, part_map1} = Map.get(attempts, a1.resource.id)
      {act_attempt2, part_map2} = Map.get(attempts, a2.resource.id)

      assert act_attempt1.lifecycle_state == :active
      assert act_attempt2.lifecycle_state == :active

      pa1 = Map.get(part_map1, "1")
      pa2 = Map.get(part_map2, "some_key")
      pa3 = Map.get(part_map2, "some_other_key")

      assert pa1.activity_attempt_id == act_attempt1.id
      assert pa2.activity_attempt_id == act_attempt2.id
      assert pa3.activity_attempt_id == act_attempt2.id

      assert pa1.lifecycle_state == :active
      assert pa2.lifecycle_state == :active
      assert pa3.lifecycle_state == :active

      assert %{attempt_number: 1, part_id: "1", hints: []} = pa1

      assert %{
               attempt_number: 1,
               part_id: "some_key",
               hints: []
             } = pa2

      assert %{
               attempt_number: 1,
               part_id: "some_other_key",
               hints: []
             } = pa3

      assert pa1.attempt_guid != pa2.attempt_guid
      assert pa3.attempt_guid != pa2.attempt_guid
      assert pa3.attempt_guid != pa1.attempt_guid
    end
  end
end
