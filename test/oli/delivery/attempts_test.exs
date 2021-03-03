defmodule Oli.Delivery.AttemptsTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.{Part, Feedback}
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Attempts.{ClientEvaluation, StudentInput}

  describe "creating the attempt tree records" do

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
        graded: true,
      }

      Seeder.add_page(map, attrs, :p1)
    end

    test "create the attempt tree", %{ p1: p1, user1: user, section: section, a1: a1, a2: a2} do

      Attempts.track_access(p1.resource.id, section.context_id, user.id)

      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      # verify that creating the attempt tree returns both activity attempts
      {:ok, {resource_attempt, attempts}} = Attempts.create_new_attempt_tree(0, nil, p1.revision, section.context_id, user.id, activity_provider)

      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

      # verify that reading the latest attempts back from the db gives us
      # the same results
      attempts = Attempts.get_latest_attempts(resource_attempt.id)
      assert Map.has_key?(attempts, a1.resource.id)
      assert Map.has_key?(attempts, a2.resource.id)

    end

    test "tracking user resource access", %{user1: user1, user2: user2, section: section, p1: %{resource: resource}} do

      Attempts.track_access(resource.id, section.context_id, user1.id)
      Attempts.track_access(resource.id, section.context_id, user1.id)

      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 1
      assert hd(entries).access_count == 2

      Attempts.track_access(resource.id, section.context_id, user2.id)
      entries = Oli.Repo.all(Oli.Delivery.Attempts.ResourceAccess)
      assert length(entries) == 2
      assert hd(entries).access_count == 2

    end

    test "starting a graded resource attempt with one user", %{p1: %{revision: revision, resource: resource}, section: section, user1: user1} do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      PageContext.create_page_context(section.context_id, revision.slug, user1)

      # Page 1
      {:ok, {resource_attempt, _activity_attempts}} =
        Attempts.start_resource_attempt(revision.slug, section.context_id, user1.id, activity_provider)

      {:error, {:active_attempt_present}} =
        Attempts.start_resource_attempt(revision.slug, section.context_id, user1.id, activity_provider)

      # No page
      {:error, {:not_found}} =
        Attempts.start_resource_attempt("garbage slug", section.context_id, user1.id, activity_provider)

      # The started attempt should be the latest attempt for this user
      latest_attempt = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user1.id)
      assert latest_attempt == resource_attempt

      # Make sure the progress state is correct for the latest resource attempt
      {:ok, {:in_progress, _ra}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user1.id, activity_provider)
    end

    test "starting a graded resource attempt with two users", %{p1: %{revision: revision, resource: resource}, section: section, user1: user1, user2: user2} do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      PageContext.create_page_context(section.context_id, revision.slug, user1)
      PageContext.create_page_context(section.context_id, revision.slug, user2)

      # User1 - same as above
      {:ok, {resource_attempt, _activity_attempts}} = Attempts.start_resource_attempt(
        revision.slug, section.context_id, user1.id, activity_provider)

      latest_attempt = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user1.id)
      assert latest_attempt == resource_attempt

      {:ok, {:in_progress, _ra}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user1.id, activity_provider)

      # User2
      # Should not have an attempt yet
      {:ok, {:not_started, _ra}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user2.id, activity_provider)

      # Start an attempt, should have same results as user1 above
      {:ok, {resource_attempt2, _activity_attempts}} =
        Attempts.start_resource_attempt(revision.slug, section.context_id, user2.id, activity_provider)

      latest_attempt2 = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user2.id)
      assert latest_attempt2 == resource_attempt2

      {:ok, {:in_progress, _ra}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user2.id, activity_provider)
    end

  end

  describe "fetching attempt records" do

    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :activity_a)
      |> Seeder.add_page(%{graded: true}, :graded_page)

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

    test "get graded resource access", %{section: section, graded_page: %{revision: revision}, user1: user1} do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      PageContext.create_page_context(section.context_id, revision.slug, user1)

      {:ok, {_resource_attempt, _activity_attempts}} = Attempts.start_resource_attempt(
        revision.slug, section.context_id, user1.id, activity_provider)

      [access | _] = Attempts.get_graded_resource_access_for_context(section.context_id)
      assert access.access_count == 2
      assert is_nil access.score
    end

    test "get latest attempt - activity attempts", %{attempt2: attempt2, activity_attempt2: activity_attempt2, activity_a: activity_a} do

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

    test "get latest attempts - part attempts", %{attempt1: attempt1} do
      [{_activity_attempt, part_attempt_map}] = Attempts.get_latest_attempts(attempt1.id)
      |> Map.values()

      [part_attempt] = part_attempt_map
      |> Map.values()

      assert %Oli.Delivery.Attempts.PartAttempt{} = part_attempt
      assert part_attempt.attempt_number == 1
      assert is_nil part_attempt.date_evaluated
    end

    test "resource attempt history", %{graded_page: %{resource: resource, revision: revision}, section: section, user1: user1} do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      PageContext.create_page_context(section.context_id, revision.slug, user1)

      {:ok, {_resource_attempt, _activity_attempts}} = Attempts.start_resource_attempt(
        revision.slug, section.context_id, user1.id, activity_provider)

      {access, attempts} = Attempts.get_resource_attempt_history(resource.id, section.context_id, user1.id)

      assert access.access_count == 1
      assert length(attempts) == 1
      assert hd(attempts).attempt_number == 1
      assert hd(attempts).date_evaluated == nil


    end

  end

  describe "submit_client_evaluations" do

    setup do
      Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)
      |> Seeder.add_activity(%{}, :publication, :project, :author, :activity_a)
      |> Seeder.add_page(%{graded: true}, :graded_page)

      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page1, :revision1, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{}}, :activity_a, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

      |> Seeder.create_resource_attempt(%{attempt_number: 2}, :user1, :page1, :revision1, :attempt2)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: %{}}, :activity_a, :attempt2, :activity_attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt2, :part1_attempt1)
    end

    test "processes a set of client evaluations for some number of parts for the given activity attempt guid", %{part1_attempt1: part1_attempt1, section: section} do

      context_id = section.context_id
      activity_attempt_guid = part1_attempt1.attempt_guid
      {:ok, feedback} = Feedback.parse(%{"id" => "1", "content" => "some-feedback"})
      client_evaluations = [
        %{attempt_guid: part1_attempt1.attempt_guid, client_evaluation: %ClientEvaluation{input: %StudentInput{input: "some-input"}, score: 1, out_of: 1, feedback: feedback}}
      ]

      assert Attempts.submit_client_evaluations(context_id, activity_attempt_guid, client_evaluations) == {:ok, [
          %{
            attempt_guid: part1_attempt1.attempt_guid,
            feedback: %Oli.Activities.Model.Feedback{content: "some-feedback", id: "1"},
            out_of: 1,
            score: 1
          }
        ]}
    end
  end

end
