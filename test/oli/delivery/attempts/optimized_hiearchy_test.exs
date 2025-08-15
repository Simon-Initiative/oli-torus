defmodule Oli.Delivery.Attempts.PageLifecycle.OptimizedHierarchyTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.PageLifecycle.{Hierarchy, VisitContext, AttemptState}

  describe "creating the attempt tree records for adaptive pages" do
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

      content3 = %{
        "stem" => "2",
        "authoring" => %{
          "parts" => [
            %{
              "id" => "final_key",
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
        |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
        |> Seeder.add_activity(%{title: "two", content: content2}, :a2)
        |> Seeder.add_activity(%{title: "three", content: content3}, :a3)
        |> Seeder.add_activity(%{title: "four", content: content3}, :a4)
        |> Seeder.add_activity(%{title: "five", content: content3}, :a5)
        |> Seeder.add_activity(%{title: "six", content: content3}, :a6)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :a1).resource.id,
              "custom" => %{"isLayer" => true}
            },
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :a2).resource.id,
              "custom" => %{"isLayer" => false}
            },
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :a3).resource.id},
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :a4).resource.id,
              "custom" => %{}
            },
            %{
              "type" => "activity-reference",
              "activity_id" => Map.get(map, :a5).resource.id,
              "custom" => %{"isBank" => true},
              "children" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => Map.get(map, :a6).resource.id,
                  "custom" => %{"isBank" => false}
                }
              ]
            }
          ],
          "advancedDelivery" => true
        },
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
      a3: a3,
      a4: a4,
      a5: a5,
      a6: a6,
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
      assert Map.has_key?(attempts, a3.resource.id)
      assert Map.has_key?(attempts, a4.resource.id)
      assert Map.has_key?(attempts, a5.resource.id)
      assert Map.has_key?(attempts, a6.resource.id)

      # verify that reading the latest attempts back from the db gives us
      # the same results
      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)
      assert Map.has_key?(attempts, a3.resource.id)
      assert Map.has_key?(attempts, a4.resource.id)
      assert Map.has_key?(attempts, a5.resource.id)
      assert Map.has_key?(attempts, a6.resource.id)

      {act_attempt1, part_map1} = Map.get(attempts, a1.resource.id)
      {act_attempt2, part_map2} = Map.get(attempts, a2.resource.id)
      {act_attempt3, part_map3} = Map.get(attempts, a3.resource.id)
      {act_attempt4, part_map4} = Map.get(attempts, a4.resource.id)
      {act_attempt5, part_map5} = Map.get(attempts, a5.resource.id)
      {act_attempt6, part_map6} = Map.get(attempts, a6.resource.id)

      assert act_attempt1.lifecycle_state == :active

      # This is perhaps the most important aspect of this test, as it guarantees that the logic
      # within the optimized create_attempt_hierarchy stored procedure correctly identifies
      # all activity references (even nested ones) and correctly categorizes the activity ref
      # as scoreable or non-scoreable
      assert act_attempt1.scoreable == false
      assert act_attempt2.scoreable == true
      assert act_attempt3.scoreable == true
      assert act_attempt4.scoreable == true
      assert act_attempt5.scoreable == false
      assert act_attempt6.scoreable == true

      pa1 = Map.get(part_map1, "1")
      pa2a = Map.get(part_map2, "some_key")
      pa2b = Map.get(part_map2, "some_other_key")
      pa3 = Map.get(part_map3, "final_key")
      pa4 = Map.get(part_map4, "final_key")
      pa5 = Map.get(part_map5, "final_key")
      pa6 = Map.get(part_map6, "final_key")

      assert pa1.activity_attempt_id == act_attempt1.id
      assert pa2a.activity_attempt_id == act_attempt2.id
      assert pa2b.activity_attempt_id == act_attempt2.id
      assert pa3.activity_attempt_id == act_attempt3.id
      assert pa4.activity_attempt_id == act_attempt4.id
      assert pa5.activity_attempt_id == act_attempt5.id
      assert pa6.activity_attempt_id == act_attempt6.id

      assert pa1.lifecycle_state == :active

      assert %{attempt_number: 1, part_id: "1", hints: []} = pa1

      assert %{
               attempt_number: 1,
               part_id: "some_key",
               hints: []
             } = pa2a

      assert %{
               attempt_number: 1,
               part_id: "some_other_key",
               hints: []
             } = pa2b
    end
  end
end
