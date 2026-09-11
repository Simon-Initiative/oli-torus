defmodule Oli.Scenarios.ProgressSimulationScenarioTest do
  use Oli.DataCase

  alias Oli.Scenarios
  alias Oli.Scenarios.RuntimeOpts

  alias Oli.Activities.ActivityRegistration
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Resources.Revision

  @scenario_path "test/oli/scenarios/data/progress_simulation.scenario.yaml"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkin(Oli.Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Oli.Repo, isolation: :serializable)
    Ecto.Adapters.SQL.Sandbox.mode(Oli.Repo, {:shared, self()})
    :ok
  end

  test "simulates learner progress across practice and graded native activities" do
    assert :ok = Scenarios.validate_file(@scenario_path)

    runtime_opts = RuntimeOpts.build()
    author = Keyword.fetch!(runtime_opts, :author)
    previous_config = Application.get_env(:oli, :preview_qa_tools)

    Application.put_env(:oli, :preview_qa_tools, default_admin_email: author.email)

    on_exit(fn -> Application.put_env(:oli, :preview_qa_tools, previous_config) end)

    result = Scenarios.execute_file(@scenario_path, runtime_opts)

    assert result.errors == []

    assert result.state.scenario_results.bulk_create_enroll_users == %{
             created: 8,
             enrolled: 8,
             reused: 0
           }

    assert result.state.scenario_results.simulate_progress == %{
             learners: 2,
             completed: 2,
             failed: 0,
             warnings: [],
             warnings_truncated: false
           }

    assert Enum.reject(result.verifications, & &1.passed) == []

    scores_by_learner =
      for learner_number <- 1..6, into: %{} do
        learner_ref = "progress_simulation_learner_#{learner_number}"
        learner = Map.fetch!(result.state.users, learner_ref)

        activity_scores =
          from(activity_attempt in ActivityAttempt,
            join: resource_attempt in ResourceAttempt,
            on: resource_attempt.id == activity_attempt.resource_attempt_id,
            join: resource_access in ResourceAccess,
            on: resource_access.id == resource_attempt.resource_access_id,
            join: revision in Revision,
            on: revision.id == activity_attempt.revision_id,
            join: registration in ActivityRegistration,
            on: registration.id == revision.activity_type_id,
            where:
              resource_access.user_id == ^learner.id and
                activity_attempt.lifecycle_state == :evaluated,
            select: activity_attempt.score,
            order_by: registration.slug
          )
          |> Repo.all()

        assert length(activity_scores) == 5
        {learner_number, Enum.sum(activity_scores)}
      end

    assert scores_by_learner[1] == 6.0
    assert scores_by_learner[2] == 6.0
    assert scores_by_learner[3] > 0.0
    assert scores_by_learner[4] > 0.0
    assert scores_by_learner[5] > 0.0
    assert scores_by_learner[5] < 6.0
    assert scores_by_learner[6] > 0.0
    assert scores_by_learner[6] < 6.0

    high_cohort_score = scores_by_learner[3] + scores_by_learner[4]
    medium_cohort_score = scores_by_learner[5] + scores_by_learner[6]
    assert high_cohort_score > medium_cohort_score

    repeated_attempt_learner = Map.fetch!(result.state.users, "progress_simulation_learner_7")

    assessment_attempts =
      Repo.all(
        from(resource_attempt in ResourceAttempt,
          join: resource_access in ResourceAccess,
          on: resource_access.id == resource_attempt.resource_access_id,
          join: revision in Revision,
          on: revision.id == resource_attempt.revision_id,
          where: resource_access.user_id == ^repeated_attempt_learner.id and revision.graded,
          select: {resource_attempt.attempt_number, resource_attempt.score},
          order_by: resource_attempt.attempt_number
        )
      )

    assert Enum.map(assessment_attempts, &elem(&1, 0)) == [1, 2, 3]
    assert assessment_attempts |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length() > 1

    assert Repo.one(
             from(activity_attempt in ActivityAttempt,
               join: resource_attempt in ResourceAttempt,
               on: resource_attempt.id == activity_attempt.resource_attempt_id,
               join: resource_access in ResourceAccess,
               on: resource_access.id == resource_attempt.resource_access_id,
               where:
                 resource_access.user_id == ^repeated_attempt_learner.id and
                   activity_attempt.lifecycle_state == :evaluated,
               select: count(activity_attempt.id)
             )
           ) == 15
  end
end
