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
      {:ok, {resource_attempt, attempts}} = Attempts.create_new_attempt_tree(nil, p1.revision, section.context_id, user.id, activity_provider)

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

      # |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user2, :page1, :revision1, :attempt2)
      # |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{}}, :activity_a, :attempt1, :activity_attempt3)
      # |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt3, :part1_attempt1)

      # make new accesses/attempts for user 2, get an "in progress" state for a resource for user1 and
      # try creating one for user 2 -> make sure get_latest_resource_attempt works to get correct attempt
      # try finishing for user 2, ensure no "in progress" attempt for user 2.
    end

    test "get latest resource attempt", %{user1: user1, user2: user2, section: section, page1: page1, activity_a: activity_a, attempt1: attempt1,
    #  attempt2: attempt2,
     revision1: revision1,
     part1_attempt1: part1_attempt1,
     activity_attempt1: activity_attempt1
     } do

      # IO.inspect(Repo.all(from a in Oli.Delivery.Attempts.ResourceAccess,
      # join: s in Oli.Delivery.Sections.Section, on: a.section_id == s.id,
      # join: ra1 in Oli.Delivery.Attempts.ResourceAttempt, on: a.id == ra1.resource_access_id,
      # left_join: ra2 in Oli.Delivery.Attempts.ResourceAttempt, on: (a.id == ra2.resource_access_id and ra1.id < ra2.id and ra1.resource_access_id == ra2.resource_access_id),
      # where: s.context_id == ^section.context_id and a.resource_id == ^page1.id and is_nil(ra2),
      # select: ra1))

      latest_attempt_user1 = Attempts.get_latest_resource_attempt(page1.id, section.context_id, user1.id)
      # latest_attempt_user2 = Attempts.get_latest_resource_attempt(page1.id, section.context_id, user2.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/2
      IO.inspect(Attempts.determine_resource_attempt_state(revision1, section.context_id, user1.id, activity_provider), label: "Resource attempt state for user 1: before")

      IO.inspect(attempt1.attempt_guid)

      Attempts.submit_part_evaluations(section.context_id, activity_attempt1.attempt_guid,
        [%{attempt_guid: part1_attempt1.attempt_guid, input: %Oli.Delivery.Attempts.StudentInput{input: "a"}}]
      )

      IO.inspect(Attempts.submit_graded_page(section.context_id, attempt1.attempt_guid), label: "Submission")

      IO.inspect(Attempts.determine_resource_attempt_state(revision1, section.context_id, user1.id, activity_provider), label: "Resource attempt state for user 1: after")

      IO.inspect(Attempts.get_graded_resource_access_for_context(section.context_id), label: "graded RA")

      # IO.inspect(latest_attempt_user1, label: "attempt user 1")
      # IO.inspect(latest_attempt_user2, label: "attempt user 2")
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
