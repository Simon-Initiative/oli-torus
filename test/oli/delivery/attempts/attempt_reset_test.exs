defmodule Oli.Delivery.Attempts.ActivityResetTest do
  use Oli.DataCase

  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Attempts.ActivityLifecycle
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate

  alias Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{StudentInput}

  def build_content(transformations) do
    %{
      "stem" => "1",
      "choices" => [1, 2, 3],
      "authoring" => %{
        "transformations" => transformations,
        "parts" => [
          %{
            "id" => "1",
            "responses" => [
              %{
                "rule" => "input like {1}",
                "score" => 10,
                "id" => "r1",
                "feedback" => %{"id" => "1", "content" => "yes"}
              },
              %{
                "rule" => "input like {2}",
                "score" => 1,
                "id" => "r2",
                "feedback" => %{"id" => "2", "content" => "almost"}
              },
              %{
                "rule" => "input like {3}",
                "score" => 0,
                "id" => "r3",
                "feedback" => %{"id" => "3", "content" => "no"}
              }
            ],
            "scoringStrategy" => "best",
            "evaluationStrategy" => "regex"
          }
        ]
      }
    }
  end

  describe "resetting an activity with transformations" do
    setup do
      content1 =
        build_content([
          %{
            "id" => "1",
            "path" => "choices",
            "operation" => "shuffle",
            "firstAttemptOnly" => true
          },
          %{
            "id" => "1",
            "path" => "responses",
            "operation" => "shuffle",
            "firstAttemptOnly" => false
          }
        ])

      content2 =
        build_content([
          %{
            "id" => "1",
            "path" => "choices",
            "operation" => "shuffle",
            "firstAttemptOnly" => false
          }
        ])

      map =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_objective("objective one", :o1)
        |> Seeder.add_activity(%{title: "one", max_attempts: 5, content: content1}, :activity1)
        |> Seeder.add_activity(%{title: "two", max_attempts: 5, content: content2}, :activity2)
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_user(%{}, :user2)

      Seeder.ensure_published(map.publication.id)

      Seeder.add_page(
        map,
        %{
          title: "practice page",
          content: %{
            "model" => [
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity1).revision.resource_id
              },
              %{
                "type" => "activity-reference",
                "activity_id" => Map.get(map, :activity2).revision.resource_id
              }
            ]
          },
          objectives: %{"attached" => [Map.get(map, :o1).resource.id]},
          graded: false
        },
        :container,
        :ungraded_page
      )
      |> Seeder.create_section_resources()
      |> Seeder.create_resource_attempt(
        %{attempt_number: 1},
        :user1,
        :ungraded_page,
        :ungraded_page_user1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content1},
        :activity1,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity1_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity1_attempt1,
        :ungraded_page_user1_activity1_attempt1_part1_attempt1
      )
      |> Seeder.create_activity_attempt(
        %{attempt_number: 1, transformed_model: content2},
        :activity2,
        :ungraded_page_user1_attempt1,
        :ungraded_page_user1_activity2_attempt1
      )
      |> Seeder.create_part_attempt(
        %{attempt_number: 1},
        %Part{id: "1", responses: [], hints: []},
        :ungraded_page_user1_activity2_attempt1,
        :ungraded_page_user1_activity2_attempt1_part1_attempt1
      )
    end

    test "ensure transformations run according to firstAttemptOnly constraints", %{
      ungraded_page_user1_activity1_attempt1_part1_attempt1: part_attempt1,
      ungraded_page_user1_activity2_attempt1_part1_attempt1: part_attempt2,
      section: section,
      ungraded_page_user1_activity1_attempt1: activity1_attempt,
      ungraded_page_user1_activity2_attempt1: activity2_attempt
    } do
      datashop_session_id_user1 = UUID.uuid4()

      part_inputs = [
        %{attempt_guid: part_attempt1.attempt_guid, input: %StudentInput{input: "1"}}
      ]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity1_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # now reset the activity, this should not have a transform - we can softly assert
      # that by ensuring that the transformed_models are the same
      {:ok, {attempt_state, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity1_attempt.attempt_guid,
          datashop_session_id_user1
        )

      attempt = Core.get_activity_attempt_by(attempt_guid: attempt_state.attemptGuid)
      assert attempt.transformed_model == activity1_attempt.transformed_model

      part_inputs = [
        %{attempt_guid: part_attempt2.attempt_guid, input: %StudentInput{input: "1"}}
      ]

      {:ok, _} =
        Evaluate.evaluate_from_input(
          section.slug,
          activity2_attempt.attempt_guid,
          part_inputs,
          datashop_session_id_user1
        )

      # now reset the second activity, this should result in a shuffle.

      :rand.seed(:exsss, {1, 2, 3})

      {:ok, {attempt_state, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity2_attempt.attempt_guid,
          datashop_session_id_user1
        )

      attempt = Core.get_activity_attempt_by(attempt_guid: attempt_state.attemptGuid)
      refute attempt.transformed_model == activity1_attempt.transformed_model
    end

    test "ensure resetting preserves selection id", %{
      ungraded_page_user1_activity1_attempt1: activity1_attempt,
      section: section
    } do
      datashop_session_id_user1 = UUID.uuid4()

      # Edit the attempt to set a selection_id
      Core.update_activity_attempt(
        activity1_attempt,
        %{selection_id: "test_selection_id"}
      )

      # now reset the activity, this should not have a transform - we can softly assert
      # that by ensuring that the transformed_models are the same
      {:ok, {attempt_state, _}} =
        ActivityLifecycle.reset_activity(
          section.slug,
          activity1_attempt.attempt_guid,
          datashop_session_id_user1
        )

      attempt = Core.get_activity_attempt_by(attempt_guid: attempt_state.attemptGuid)
      assert attempt.transformed_model == activity1_attempt.transformed_model
      assert attempt.selection_id == "test_selection_id"
    end
  end
end
