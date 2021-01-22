defmodule Oli.Delivery.AttemptsSubmissionTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.{ActivityAttempt, PartAttempt, StudentInput, Snapshot}


  describe "resetting an activity" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"rule" => "input like {a}", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", max_attempts: 2, content: content}, :activity)
      |> Seeder.add_user(%{}, :user1)
      |> Seeder.add_user(%{}, :user2)

      Seeder.add_page(map, %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity).revision.resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }, :page)
      |> Seeder.add_page(%{
        title: "page2",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity).revision.resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
        graded: true,
      }, :graded_page)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :graded_page, :attempt2)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity, :attempt2, :activity_attempt2)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt2, :part1_attempt2)

      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user2, :graded_page, :attempt3)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity, :attempt3, :activity_attempt3)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt3, :part1_attempt3)

    end

    test "get_latest_resource_attempt gives an unevaluated attempt with 1 user", %{ page: %{ resource: resource }, user1: user1,
    section: section, attempt1: resource_attempt1 } do
      resource_attempt = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user1.id)

      assert resource_attempt == resource_attempt1
      assert is_nil(resource_attempt.date_evaluated)
      assert is_nil(resource_attempt.score)
    end

    test "get_latest_resource_attempt gives two different attempts with 2 users", %{ page: %{ resource: resource }, user1: user1,
    user2: user2, section: section, attempt1: resource_attempt1, attempt2: resource_attempt2 } do
      resource_attempt_user1 = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user1.id)
      resource_attempt_user2 = Attempts.get_latest_resource_attempt(resource.id, section.context_id, user2.id)

      assert resource_attempt1 == resource_attempt_user1
      assert resource_attempt2 == resource_attempt_user2

      assert resource_attempt1 != resource_attempt2
    end

    test "determine_resource_attempt_state works for graded pages with 1 user", %{ graded_page: %{ revision: revision },
      user1: user1, section: section, part1_attempt2: part_attempt, activity_attempt2: activity_attempt,
      attempt2: resource_attempt1,
    } do
      activity_provider = &Oli.Delivery.ActivityProvider.provide/2

      {:ok, {:in_progress, _resource_attempt}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user1.id, activity_provider)

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, _evals} = Attempts.submit_part_evaluations(
        section.context_id, activity_attempt.attempt_guid, part_inputs)

      IO.inspect(Attempts.submit_graded_page(section.context_id, resource_attempt1.attempt_guid))

      {:ok, {:not_started, _resource_attempt}} = Attempts.determine_resource_attempt_state(
        revision, section.context_id, user1.id, activity_provider)

    end

    test "determine_resource_attempt_state works for graded pages with 2 users" do

    end



    # IO.inspect(resource_attempt)

    # get_resource_state(resource_revision, context_id, user_id, activity_provider) do


    test "processing a submission", %{ activity: %{ revision: activity_revision }, page: %{ revision: page_revision }, user1: user,
      part1_attempt1: part_attempt, section: section, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]

      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]}
        = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission rolled up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # now reset the activity
      {:ok, {attempt_state, _}} = Attempts.reset_activity(section.context_id, activity_attempt.attempt_guid)

      assert attempt_state.dateEvaluated == nil
      assert attempt_state.score == nil
      assert attempt_state.outOf == nil
      assert length(attempt_state.parts) == 1
      assert attempt_state.hasMoreAttempts == false

      # now try to reset when there are no more attempts
      assert {:error, {:no_more_attempts}} == Attempts.reset_activity(section.context_id, attempt_state.attemptGuid)

      # verify that a snapshot record was created properly
      [%Snapshot{} = snapshot] = Oli.Repo.all(Snapshot)

      assert snapshot.score == 10
      assert snapshot.out_of == 10
      assert snapshot.graded == false
      assert snapshot.part_attempt_id == part_attempt.id
      assert snapshot.part_attempt_number == 1
      assert snapshot.attempt_number == 1
      assert snapshot.resource_attempt_number == 1
      assert snapshot.section_id == section.id
      assert snapshot.user_id == user.id
      assert snapshot.activity_id == updated_attempt.resource_id
      assert snapshot.resource_id == page_revision.resource_id
      assert snapshot.revision_id == activity_revision.id

    end

    # This test case ensures that the following scenario works correctly:
    #
    # 1. Student opens a resource with an activity that has a maximum of TWO attempts in window tab A.
    # 2. Student submits a response (exhausting attempt 1).
    # 3. Student opens a new window tab B with the same resource. This generates a new activity attempt (attempt 2)
    # 4. Student submits a response for tab B. (exhausting attempt 2)
    # 5. Student clicks "Reset" in tab A.  This should be rejected.
    test "handling concurrent reset attempts", %{ part1_attempt1: part_attempt, section: section, activity_attempt1: activity_attempt} do

      # Submit in tab A:
      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, _} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      # now reset the activity, this is a simulation of the student
      # opening the resource in tab B.
      {:ok, {attempt_state, _}} = Attempts.reset_activity(section.context_id, activity_attempt.attempt_guid)
      assert attempt_state.hasMoreAttempts == false

      # now try to reset the guid from the first attempt, simulating the
      # student clicking 'Reset' in tab A.
      assert {:error, {:no_more_attempts}} == Attempts.reset_activity(section.context_id, activity_attempt.attempt_guid)

    end

  end

  describe "processing a one part submission" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"rule" => "input like {a}", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :activity)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity).revision.resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.add_page(map, attrs, :page)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

    end

    test "processing a submission", %{ part1_attempt1: part_attempt, section: section, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission rolled up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

    end

    test "processing a different submission", %{ part1_attempt1: part_attempt, section: section, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "b"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      assert attempt_guid == part_attempt.attempt_guid
      assert score == 1
      assert out_of == 10
      assert id == "2"

    end

    test "processing a submission whose input matches no response", %{ section: section, part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "d"}}]
      {:error, error} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      assert error == "no matching response found"

    end

  end

  describe "processing a multipart submission" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"rule" => "input like {a}", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"},
            %{"id" => "2", "responses" => [
              %{"rule" => "input like {a}", "score" => 2, "id" => "r1", "feedback" => %{"id" => "4", "content" => "yes"}},
              %{"rule" => "input like {b}", "score" => 1, "id" => "r2", "feedback" => %{"id" => "5", "content" => "almost"}},
              %{"rule" => "input like {c}", "score" => 0, "id" => "r3", "feedback" => %{"id" => "6", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :publication, :project, :author, :activity)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity).revision.resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource.id]}
      }

      Seeder.add_page(map, attrs, :page)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "2", responses: [], hints: []}, :activity_attempt1, :part2_attempt1)

    end

    test "processing a submission with just one of the parts submitted", %{ section: section, part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      # verify that the submission did NOT roll up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == nil
      assert updated_attempt.out_of == nil
      assert updated_attempt.date_evaluated == nil

    end

    test "processing a submission with all parts submitted", %{ section: section, part1_attempt1: part_attempt, part2_attempt1: part2_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [
        %{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}},
        %{attempt_guid: part2_attempt.attempt_guid, input: %StudentInput{input: "b"}},
      ]
      {:ok, [
        %{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} },
        %{attempt_guid: attempt_guid2, out_of: out_of2, score: score2, feedback: %{id: id2} },
      ]} = Attempts.submit_part_evaluations(section.context_id, activity_attempt.attempt_guid, part_inputs)

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      assert attempt_guid2 == part2_attempt.attempt_guid
      assert score2 == 1
      assert out_of2 == 2
      assert id2 == "5"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      updated_attempt = Oli.Repo.get!(PartAttempt, part2_attempt.id)
      assert updated_attempt.score == 1
      assert updated_attempt.out_of == 2
      refute updated_attempt.date_evaluated == nil

      # verify that the submission did roll up to the activity attempt
      # with the fact that the scoring strategy defaults to best
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

    end

  end

end
