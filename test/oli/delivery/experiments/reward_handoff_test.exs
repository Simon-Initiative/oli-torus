defmodule Oli.Delivery.Experiments.RewardHandoffTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Experiments.RewardHandoff
  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp
  alias Oli.Delivery.Attempts.Core.ActivityAttempt
  alias Oli.Experiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, RecordExposureRequest, Scope}
  alias Oli.Experiments.Schemas.{Condition, DecisionPoint, Outcome, PolicyUpdate, Reward}
  alias Oli.Resources.ResourceType

  describe "record_evaluated_activity/1" do
    test "records full-credit outcome and reward value 1.0" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 1.0, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      outcome = Repo.one!(Outcome)
      reward = Repo.one!(Reward)

      assert outcome.activity_attempt_id == activity_attempt.id
      assert outcome.resource_attempt_id == activity_attempt.resource_attempt_id
      assert outcome.activity_resource_id == activity_attempt.resource_id
      assert outcome.score == 1.0
      assert outcome.out_of == 1.0

      assert outcome.metadata == %{
               "attempt_number" => activity_attempt.attempt_number,
               "source" => "activity_attempt:evaluated"
             }

      assert reward.outcome_id == outcome.id
      assert reward.reward_value == 1.0
      assert reward.reward_source == "activity_attempt:evaluated"

      assert reward.metadata == %{
               "attempt_number" => activity_attempt.attempt_number,
               "binary_rule" => "full_credit"
             }
    end

    test "records non-full-credit reward value 0.0" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 0.5, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert Repo.one!(Reward).reward_value == 0.0
    end

    test "accepts activity attempt guids for bulk/finalization handoff paths" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 1.0, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.attempt_guid)

      assert Repo.aggregate(Outcome, :count, :id) == 1
      assert Repo.aggregate(Reward, :count, :id) == 1
    end

    test "reprocessing an evaluated attempt reuses outcome and reward idempotently" do
      %{activity_attempt: activity_attempt} =
        setup_reward_context(score: 1.0, out_of: 1.0, algorithm: :thompson_sampling)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)
      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert Repo.aggregate(Outcome, :count, :id) == 1
      assert Repo.aggregate(Reward, :count, :id) == 1
      assert Repo.aggregate(PolicyUpdate, :count, :id) == 1
    end

    test "returns ok without records when no experiment assignment is eligible" do
      %{activity_attempt: activity_attempt} = setup_reward_context(assign?: false)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert Repo.aggregate(Outcome, :count, :id) == 0
      assert Repo.aggregate(Reward, :count, :id) == 0
    end

    test "rollup persists evaluated attempt when reward handoff fails" do
      %{activity_attempt: activity_attempt} =
        setup_reward_context(assign?: false, lifecycle_state: :active, score: nil, out_of: nil)

      insert(:part_attempt,
        activity_attempt: activity_attempt,
        lifecycle_state: :evaluated,
        score: 1.0,
        out_of: 1.0,
        date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
      )

      assert :ok =
               RollUp.rollup_evaluated(activity_attempt.attempt_guid,
                 reward_handoff: fn _activity_attempt_id -> {:error, :forced_failure} end
               )

      updated_attempt = Repo.get!(ActivityAttempt, activity_attempt.id)
      assert updated_attempt.lifecycle_state == :evaluated
      assert updated_attempt.score == 1.0
      assert updated_attempt.out_of == 1.0
    end
  end

  defp setup_reward_context(opts) do
    score = Keyword.get(opts, :score, 1.0)
    out_of = Keyword.get(opts, :out_of, 1.0)
    assign? = Keyword.get(opts, :assign?, true)
    algorithm = Keyword.get(opts, :algorithm, :weighted_random)
    lifecycle_state = Keyword.get(opts, :lifecycle_state, :evaluated)

    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section =
      insert(:section, institution: institution, base_project: project, has_experiments: true)

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    alternatives_revision = insert(:revision)
    activity_revision = insert(:revision, resource_type_id: ResourceType.id_for_activity())

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        content: page_content(alternatives_revision.resource_id, activity_revision.resource_id)
      )

    insert(:project_resource,
      project_id: project.id,
      resource_id: alternatives_revision.resource_id
    )

    insert(:project_resource, project_id: project.id, resource_id: page_revision.resource_id)

    insert(:section_resource,
      section: section,
      project: project,
      resource_id: page_revision.resource_id
    )

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    resource_access =
      insert(:resource_access,
        section: section,
        user: user,
        resource: page_revision.resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        content: page_revision.content
      )

    activity_attempt =
      insert(:activity_attempt,
        resource_attempt: resource_attempt,
        revision: activity_revision,
        resource: activity_revision.resource,
        lifecycle_state: lifecycle_state,
        score: score,
        out_of: out_of,
        date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
      )

    scope = %Scope{
      institution_id: institution.id,
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }

    if assign? do
      create_assignment_and_exposure(scope, alternatives_revision, algorithm)
    end

    %{activity_attempt: activity_attempt, scope: scope}
  end

  defp create_assignment_and_exposure(%Scope{} = scope, alternatives_revision, algorithm) do
    {:ok, definition} =
      Experiments.create_experiment(%CreateExperimentRequest{
        scope: scope,
        slug: "reward-#{System.unique_integer([:positive])}",
        name: "Reward experiment",
        algorithm: algorithm
      })

    {:ok, active} =
      Experiments.activate_experiment(definition.id, %LifecycleRequest{scope: scope})

    decision_point =
      %DecisionPoint{}
      |> DecisionPoint.changeset(%{
        experiment_id: active.id,
        alternatives_resource_id: alternatives_revision.resource_id,
        alternatives_revision_id: alternatives_revision.id,
        decision_point_key: "alternatives:#{alternatives_revision.resource_id}"
      })
      |> Repo.insert!()

    %Condition{}
    |> Condition.changeset(%{
      experiment_id: active.id,
      decision_point_id: decision_point.id,
      condition_code: "condition-a",
      option_id: "alt-a",
      label: "Condition A",
      weight: 1.0,
      position: 0
    })
    |> Repo.insert!()

    {:ok, assignment} =
      Experiments.assign_condition(%Oli.Experiments.AssignConditionRequest{
        scope: scope,
        alternatives_resource_id: alternatives_revision.resource_id,
        alternatives_revision_id: alternatives_revision.id,
        decision_point_key: "alternatives:#{alternatives_revision.resource_id}",
        available_condition_codes: ["condition-a"]
      })

    {:ok, _exposure} =
      Experiments.record_exposure(%RecordExposureRequest{
        scope: scope,
        assignment_id: assignment.assignment_id,
        content_revision_id: alternatives_revision.id,
        idempotency_key: "exposure:#{assignment.assignment_id}"
      })
  end

  defp page_content(alternatives_resource_id, activity_resource_id) do
    %{
      "model" => [
        %{
          "type" => "alternatives",
          "alternatives_id" => alternatives_resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "value" => "alt-a",
              "children" => [
                %{
                  "type" => "activity-reference",
                  "activity_id" => activity_resource_id,
                  "children" => []
                }
              ]
            },
            %{"type" => "alternative", "value" => "alt-b", "children" => []}
          ]
        }
      ]
    }
  end
end
