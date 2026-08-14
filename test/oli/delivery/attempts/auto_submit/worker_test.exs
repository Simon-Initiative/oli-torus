defmodule Oli.Delivery.Attempts.AutoSubmit.WorkerTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Experiments.RewardHandoffWorker
  alias Oli.Delivery.Settings.Combined
  alias Oli.Activities.Model.Part
  alias Oli.Experiments.Schemas.{AcceptedReward, PolicyState}
  alias Oli.Test.ExperimentRewardSetup

  @automatic_content %{
    "stem" => "1",
    "authoring" => %{
      "parts" => [
        %{
          "id" => "1",
          "responses" => [],
          "scoringStrategy" => "best",
          "evaluationStrategy" => "regex",
          "gradingApproach" => "automatic"
        }
      ]
    }
  }

  describe "perform/1" do
    setup do
      context =
        Seeder.base_project_with_resource2()
        |> Seeder.create_section()
        |> Seeder.add_user(%{}, :user1)
        |> Seeder.add_activity(
          %{title: "auto-submit activity"},
          :publication,
          :project,
          :author,
          :activity_a
        )
        |> Seeder.create_section_resources()
        |> Seeder.create_resource_attempt(
          %{attempt_number: 1},
          :user1,
          :page2,
          :revision2,
          :attempt1
        )
        |> add_automatic_activity(:attempt1, :activity_a, :attempt_1a)

      Oli.Resources.update_revision(context.revision2, %{graded: true})

      reward_context =
        ExperimentRewardSetup.create(context.project, context.section, context.attempt1)

      Map.put(context, :reward_context, reward_context)
    end

    @tag capture_log: true
    test "enqueues and applies the reward after an evaluated auto-submit", %{
      section: section,
      attempt1: attempt,
      reward_context: reward_context
    } do
      assert {:ok, :ok} =
               perform_job(Worker, %{
                 "attempt_guid" => attempt.attempt_guid,
                 "section_slug" => section.slug,
                 "datashop_session_id" => UUID.uuid4()
               })

      resource_attempt = Oli.Repo.reload!(attempt)
      assert resource_attempt.lifecycle_state == :evaluated

      assert_enqueued(
        worker: RewardHandoffWorker,
        args: %{"resource_attempt_id" => resource_attempt.id}
      )

      assert :ok =
               perform_job(RewardHandoffWorker, %{
                 "resource_attempt_id" => resource_attempt.id
               })

      assert Oli.Repo.aggregate(AcceptedReward, :count) == 1

      policy_state = Oli.Repo.get!(PolicyState, reward_context.policy_state.id)
      assert policy_state.reward_success_count + policy_state.reward_failure_count == 1

      posterior = policy_state.state["condition-a"]
      assert posterior["posterior_alpha"] + posterior["posterior_beta"] == 3.0
    end
  end

  describe "maybe_schedule_auto_submit/4" do
    test "schedules a job when there is a due_by deadline" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :due_by,
        end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
        time_limit: 0,
        grace_period: 0,
        late_submit: :disallow
      }

      assert {:ok, job_id} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      assert job_id

      assert_enqueued(
        worker: Worker,
        args: %{
          "attempt_guid" => attempt.attempt_guid,
          "section_slug" => "section-slug",
          "datashop_session_id" => "datashop"
        }
      )
    end

    test "does not schedule when there is no due date and no time limit" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :read_by,
        end_date: nil,
        time_limit: 0,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end

    test "does not schedule for suggested dates even when late policy disallows start" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :read_by,
        end_date: DateTime.add(DateTime.utc_now(), 3600, :second),
        time_limit: 0,
        late_start: :disallow,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end

    test "does not schedule when the deadline is already in the past" do
      attempt = %ResourceAttempt{
        attempt_guid: "attempt-guid",
        inserted_at: DateTime.utc_now()
      }

      settings = %Combined{
        scheduling_type: :due_by,
        end_date: DateTime.add(DateTime.utc_now(), -3600, :second),
        time_limit: 0,
        grace_period: 0,
        late_submit: :disallow
      }

      assert {:ok, :not_scheduled} =
               Worker.maybe_schedule_auto_submit(settings, "section-slug", attempt, "datashop")

      refute_enqueued(worker: Worker, args: %{"attempt_guid" => attempt.attempt_guid})
    end
  end

  defp add_automatic_activity(map, resource_attempt_tag, activity_tag, activity_attempt_tag) do
    map
    |> Seeder.create_activity_attempt(
      %{attempt_number: 1, transformed_model: @automatic_content, lifecycle_state: :active},
      activity_tag,
      resource_attempt_tag,
      activity_attempt_tag
    )
    |> Seeder.create_part_attempt(
      %{
        attempt_number: 1,
        grading_approach: :automatic,
        lifecycle_state: :active,
        part_id: "1"
      },
      %Part{id: "1", responses: [], hints: [], grading_approach: :automatic},
      activity_attempt_tag
    )
  end
end
