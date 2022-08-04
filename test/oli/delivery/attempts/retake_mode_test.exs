defmodule Oli.Delivery.Attempts.PageLifecycle.RetakeModeTest do
  use Oli.DataCase

  alias Oli.Delivery.Attempts.Core, as: Attempts
  alias Oli.Delivery.Attempts.PageLifecycle.{Hierarchy, VisitContext}

  describe "targeted retake mode" do
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

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
        |> Seeder.add_activity(%{title: "two", content: content1}, :a2)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      attrs = %{
        title: "page1",
        retake_mode: :targeted,
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
      |> Seeder.add_page(attrs, :p2)
      |> Seeder.create_section_resources()
    end

    test "targeted retake mode for one activity out of two", %{
      p1: p1,
      user1: user,
      section: section,
      a1: a1,
      a2: a2,
      publication: pub
    } do
      Attempts.track_access(p1.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/4
      datashop_session_id = UUID.uuid4()

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)
      {attempt, part_map} = Map.get(attempts, a1.resource.id)

      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 1})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{score: 1, out_of: 1, response: %{input: "this was right"}})

      {attempt, part_map} = Map.get(attempts, a2.resource.id)
      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 3})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{score: 1, out_of: 3, response: %{input: "this was wrong"}})

      {:ok, resource_attempt2} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: resource_attempt,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt2.id)

      # Ensure that the new part attempt records carried forward the state of only the correct
      # activity attempt from the previous resource attempt
      {_, part_map} = Map.get(attempts, a1.resource.id)
      assert Map.get(part_map, "1").response == %{"input" => "this was right"}
      {_, part_map} = Map.get(attempts, a2.resource.id)
      assert Map.get(part_map, "1").response == nil
    end

    test "targeted retake mode for all activities", %{
      p1: p1,
      user1: user,
      section: section,
      a1: a1,
      a2: a2,
      publication: pub
    } do
      Attempts.track_access(p1.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/4
      datashop_session_id = UUID.uuid4()

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)
      {attempt, part_map} = Map.get(attempts, a1.resource.id)

      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 1})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{score: 1, out_of: 1, response: %{input: "this was right"}})

      {attempt, part_map} = Map.get(attempts, a2.resource.id)
      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 1})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{
        score: 1,
        out_of: 1,
        response: %{input: "this was right, also"}
      })

      {:ok, resource_attempt2} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: resource_attempt,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt2.id)

      # Ensure that the new part attempt records carried forward the state of only the correct
      # activity attempt from the previous resource attempt
      {_, part_map} = Map.get(attempts, a1.resource.id)
      assert Map.get(part_map, "1").response == %{"input" => "this was right"}
      {_, part_map} = Map.get(attempts, a2.resource.id)
      assert Map.get(part_map, "1").response == %{"input" => "this was right, also"}
    end

    test "targeted retake mode disabled when page revision changes", %{
      p1: p1,
      p2: p2,
      user1: user,
      section: section,
      a1: a1,
      a2: a2,
      publication: pub
    } do
      Attempts.track_access(p1.resource.id, section.id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/4
      datashop_session_id = UUID.uuid4()

      {:ok, resource_attempt} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: nil,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt.id)
      {attempt, part_map} = Map.get(attempts, a1.resource.id)

      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 1})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{score: 1, out_of: 1, response: %{input: "this was right"}})

      {attempt, part_map} = Map.get(attempts, a2.resource.id)
      Attempts.update_activity_attempt(attempt, %{score: 1, out_of: 3})

      Map.get(part_map, "1")
      |> Attempts.update_part_attempt(%{score: 1, out_of: 3, response: %{input: "this was wrong"}})

      # We can safely simulate moving ahead to a new publication for the page by
      # changing the revision id on the resource_attempt
      {:ok, resource_attempt} =
        Attempts.update_resource_attempt(resource_attempt, %{revision_id: p2.revision.id})

      {:ok, resource_attempt2} =
        Hierarchy.create(%VisitContext{
          latest_resource_attempt: resource_attempt,
          page_revision: p1.revision,
          section_slug: section.slug,
          datashop_session_id: datashop_session_id,
          user_id: user.id,
          activity_provider: activity_provider,
          blacklisted_activity_ids: [],
          publication_id: pub.id
        })

      attempts = Hierarchy.get_latest_attempts(resource_attempt2.id)

      # Ensure that the new part attempt records carried forward the state of only the correct
      # activity attempt from the previous resource attempt
      {_, part_map} = Map.get(attempts, a1.resource.id)
      assert Map.get(part_map, "1").response == nil
      {_, part_map} = Map.get(attempts, a2.resource.id)
      assert Map.get(part_map, "1").response == nil
    end
  end
end
