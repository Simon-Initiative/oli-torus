defmodule Oli.Delivery.AttemptsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.Part

  describe "creating the attempt tree" do


    setup do

      content1 = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }
      content2 = %{
        "stem" => "2",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }


      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content1}, :a1)
      |> Seeder.add_activity(%{title: "two", content: content2}, :a2)
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

    test "create the attempt tree", %{ p1: p1, user1: user, section: section, a1: a1, a2: a2} do

      Attempts.track_access(p1.resource.id, section.context_id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      # verify that creating the attempt tree returns both activity attempts
      {resource_attempt, attempts} = Attempts.create_new_attempt_tree(nil, p1.revision, section.context_id, user.id, activity_provider)
      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      # verify that reading the latest attempts back from the db gives us
      # the same results
      attempts = Attempts.get_latest_attempts(resource_attempt.id)
      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

    end

  end

  describe "fetching existing attempts" do

    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :activity_a)

      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{}}, :activity_a, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

      |> Seeder.create_resource_attempt(%{attempt_number: 2}, :user1, :page1, :revision1, :attempt2)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{}}, :activity_a, :attempt2, :activity_attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt2, :part1_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 2}, %Part{id: "1", responses: [], hints: []}, :activity_attempt2, :part1_attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 3}, %Part{id: "1", responses: [], hints: []}, :activity_attempt2, :part1_attempt3)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "2", responses: [], hints: []}, :activity_attempt2, :part2_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "3", responses: [], hints: []}, :activity_attempt2, :part3_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 2}, %Part{id: "3", responses: [], hints: []}, :activity_attempt2, :part3_attempt2)
    end

    test "creating an access record", %{user1: user1, user2: user2, section: section, page1: page1} do

      Attempts.track_access(page1.id, section.context_id, user1.id)
      Attempts.track_access(page1.id, section.context_id, user1.id)

      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 1
      assert hd(entries).access_count == 4

      Attempts.track_access(page1.id, section.context_id, user2.id)
      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 2
      assert hd(entries).access_count == 4

    end

    test "fetching attempt records", %{attempt2: attempt2, activity_attempt2: activity_attempt2, activity_a: activity_a} do

      results = Attempts.get_latest_attempts(attempt2.id)

      assert length(Map.keys(results)) == 1
      assert Map.has_key?(results, activity_a.resource.id)

      id = activity_attempt2.id

      case results[activity_a.resource.id] do
        {%{id: ^id}, map} -> assert map["1"].attempt_number == 3
        _ -> assert false
      end

      case results[activity_a.resource.id] do
        {%{id: ^id}, map} -> assert map["2"].attempt_number == 1
        _ -> assert false
      end

      case results[activity_a.resource.id] do
        {%{id: ^id}, map} -> assert map["3"].attempt_number == 2
        _ -> assert false
      end

    end

  end

end
