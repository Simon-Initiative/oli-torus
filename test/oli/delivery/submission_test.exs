defmodule Oli.Delivery.AttemptsSubmissionTest do

  use Oli.DataCase

  alias Oli.Delivery.Attempts
  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.{ActivityAttempt, PartAttempt, StudentInput}


  describe "resetting an activity" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"match" => "a", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"match" => "b", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"match" => "c", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :publication, :project, :author, :activity_resource, :activity_revision)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity_revision).resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource_id]}
      }

      Seeder.add_page(map, attrs, :page_resource, :page_revision)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page_resource, :page_revision, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity_resource, :activity_revision, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

    end

    test "processing a submission", %{ part1_attempt1: part_attempt, section: section, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

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
      {:ok, attempt_state, _} = Attempts.reset_activity(section.context_id, activity_attempt.attempt_guid)

      assert attempt_state.dateEvaluated == nil
      assert attempt_state.score == nil
      assert attempt_state.outOf == nil
      assert length(attempt_state.parts) == 1

    end

  end

  describe "processing a one part submission" do

    setup do

      content = %{
        "stem" => "1",
        "authoring" => %{
          "parts" => [
            %{"id" => "1", "responses" => [
              %{"match" => "a", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"match" => "b", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"match" => "c", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :publication, :project, :author, :activity_resource, :activity_revision)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity_revision).resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource_id]}
      }

      Seeder.add_page(map, attrs, :page_resource, :page_revision)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page_resource, :page_revision, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity_resource, :activity_revision, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)

    end

    test "processing a submission", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

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

    test "processing a different submission", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "b"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

      assert attempt_guid == part_attempt.attempt_guid
      assert score == 1
      assert out_of == 10
      assert id == "2"

    end

    test "processing a submission whose input matches no response", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "d"}}]
      {:error, error} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

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
              %{"match" => "a", "score" => 10, "id" => "r1", "feedback" => %{"id" => "1", "content" => "yes"}},
              %{"match" => "b", "score" => 1, "id" => "r2", "feedback" => %{"id" => "2", "content" => "almost"}},
              %{"match" => "c", "score" => 0, "id" => "r3", "feedback" => %{"id" => "3", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"},
            %{"id" => "2", "responses" => [
              %{"match" => "a", "score" => 2, "id" => "r1", "feedback" => %{"id" => "4", "content" => "yes"}},
              %{"match" => "b", "score" => 1, "id" => "r2", "feedback" => %{"id" => "5", "content" => "almost"}},
              %{"match" => "c", "score" => 0, "id" => "r3", "feedback" => %{"id" => "6", "content" => "no"}}
            ], "scoringStrategy" => "best", "evaluationStrategy" => "regex"}
          ]
        }
      }

      map = Seeder.base_project_with_resource2()
      |> Seeder.create_section()
      |> Seeder.add_objective("objective one", :o1)
      |> Seeder.add_activity(%{title: "one", content: content}, :publication, :project, :author, :activity_resource, :activity_revision)
      |> Seeder.add_user(%{}, :user1)

      attrs = %{
        title: "page1",
        content: %{
          "model" => [
            %{"type" => "activity-reference", "activity_id" => Map.get(map, :activity_revision).resource_id}
          ]
        },
        objectives: %{"attached" => [Map.get(map, :o1).resource_id]}
      }

      Seeder.add_page(map, attrs, :page_resource, :page_revision)
      |> Seeder.create_resource_attempt(%{attempt_number: 1}, :user1, :page_resource, :page_revision, :attempt1)
      |> Seeder.create_activity_attempt(%{attempt_number: 1, transformed_model: content}, :activity_resource, :activity_revision, :attempt1, :activity_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "1", responses: [], hints: []}, :activity_attempt1, :part1_attempt1)
      |> Seeder.create_part_attempt(%{attempt_number: 1}, %Part{id: "2", responses: [], hints: []}, :activity_attempt1, :part2_attempt1)

    end

    test "processing a submission with just one of the parts submitted", %{ part1_attempt1: part_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [%{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}}]
      {:ok, [%{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} }]} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

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

    test "processing a submission with all parts submitted", %{ part1_attempt1: part_attempt, part2_attempt1: part2_attempt, activity_attempt1: activity_attempt} do

      part_inputs = [
        %{attempt_guid: part_attempt.attempt_guid, input: %StudentInput{input: "a"}},
        %{attempt_guid: part2_attempt.attempt_guid, input: %StudentInput{input: "a"}},
      ]
      {:ok, [
        %{attempt_guid: attempt_guid, out_of: out_of, score: score, feedback: %{id: id} },
        %{attempt_guid: attempt_guid2, out_of: out_of2, score: score2, feedback: %{id: id2} },
      ]} = Attempts.submit_part_evaluations(activity_attempt.attempt_guid, part_inputs)

      # verify the returned feedback was what we expected
      assert attempt_guid == part_attempt.attempt_guid
      assert score == 10
      assert out_of == 10
      assert id == "1"

      assert attempt_guid2 == part2_attempt.attempt_guid
      assert score2 == 2
      assert out_of2 == 2
      assert id2 == "4"

      # verify the part attempt record was updated correctly
      updated_attempt = Oli.Repo.get!(PartAttempt, part_attempt.id)
      assert updated_attempt.score == 10
      assert updated_attempt.out_of == 10
      refute updated_attempt.date_evaluated == nil

      updated_attempt = Oli.Repo.get!(PartAttempt, part2_attempt.id)
      assert updated_attempt.score == 2
      assert updated_attempt.out_of == 2
      refute updated_attempt.date_evaluated == nil

      # verify that the submission did roll up to the activity attempt
      updated_attempt = Oli.Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.score == 12
      assert updated_attempt.out_of == 12
      refute updated_attempt.date_evaluated == nil

    end

  end

end
