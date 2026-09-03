defmodule Oli.Delivery.Experiments.AssessmentRewardHandoffTest do
  use Oli.DataCase
  use Oban.Testing, repo: Oli.Repo

  import Oli.Factory
  import Ecto.Query

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.{Events.Context, StatementBundle, StatementFactory}
  alias Oli.Delivery.Experiments.RewardHandoff
  alias Oli.Delivery.Snapshots.Worker, as: SnapshotWorker
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Experiments.Policies.ThompsonSampling

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    AssessmentBinding,
    Assignment,
    Condition,
    ExperimentDefinition,
    ExperimentSection,
    Intervention,
    PolicyState
  }

  describe "record_evaluated_resource_attempt/1" do
    test "gates reward processing to sections in active Thompson Sampling experiments" do
      project = insert(:project)
      active_section = insert(:section, base_project: project)
      inactive_section = insert(:section, base_project: project)

      experiment =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(%{
          project_id: project.id,
          slug: "active-reward-experiment",
          name: "Active reward experiment",
          state: :active,
          algorithm: :thompson_sampling,
          alternatives_resource_id: insert(:resource).id
        })
        |> Repo.insert!()

      %ExperimentSection{}
      |> ExperimentSection.changeset(%{
        experiment_id: experiment.id,
        section_id: active_section.id
      })
      |> Repo.insert!()

      assert RewardHandoff.active_thompson_section?(active_section.id)
      refute RewardHandoff.active_thompson_section?(inactive_section.id)

      experiment
      |> ExperimentDefinition.changeset(%{state: :completed})
      |> Repo.update!()

      refute RewardHandoff.active_thompson_section?(active_section.id)
    end

    test "accepts the first evaluated page attempt at the inclusive binding threshold" do
      context = setup_context(score: 3.0, out_of: 4.0, threshold: "0.75")

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      reward = Repo.one!(AcceptedReward)
      assert reward.assignment_id == context.assignment.id
      assert reward.reward == 1
      assert Decimal.equal?(reward.normalized_score, Decimal.new("0.75"))

      policy_state = Repo.get!(PolicyState, context.policy_state.id)
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 0
      assert policy_state.state["condition-a"]["posterior_alpha"] == 2.0
      assert policy_state.state["condition-a"]["posterior_beta"] == 1.0
    end

    test "records a failure below a binding-specific threshold and accepts threshold zero" do
      below = setup_context(score: 0.74, out_of: 1.0, threshold: "0.75")
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(below.resource_attempt.id)
      assert Repo.get_by!(AcceptedReward, assessment_binding_id: below.binding.id).reward == 0

      zero = setup_context(score: 0.0, out_of: 1.0, threshold: "0.0")
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(zero.resource_attempt.id)
      assert Repo.get_by!(AcceptedReward, assessment_binding_id: zero.binding.id).reward == 1
    end

    test "requires full credit at threshold one and ignores activity-attempt scores" do
      context = setup_context(score: 0.99, out_of: 1.0, threshold: "1.0")

      insert(:activity_attempt,
        resource_attempt: context.resource_attempt,
        lifecycle_state: :evaluated,
        score: 1.0,
        out_of: 1.0
      )

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      reward = Repo.get_by!(AcceptedReward, assessment_binding_id: context.binding.id)
      assert reward.reward == 0

      policy_state = Repo.get!(PolicyState, context.policy_state.id)
      assert policy_state.reward_success_count == 0
      assert policy_state.reward_failure_count == 1
      assert policy_state.state["condition-a"]["posterior_alpha"] == 1.0
      assert policy_state.state["condition-a"]["posterior_beta"] == 2.0
    end

    test "a pending first attempt blocks a later evaluated attempt" do
      context = setup_context(score: 1.0, out_of: 1.0, attempt_number: 2)

      insert(:resource_attempt,
        resource_access: context.resource_access,
        revision: context.page_revision,
        attempt_number: 1,
        lifecycle_state: :submitted,
        score: 1.0,
        out_of: 1.0
      )

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      assert Repo.aggregate(AcceptedReward, :count) == 0
    end

    test "the pending first attempt is accepted once evaluated" do
      context = setup_context(score: 1.0, out_of: 1.0, attempt_number: 2)

      first_attempt =
        insert(:resource_attempt,
          resource_access: context.resource_access,
          revision: context.page_revision,
          attempt_number: 1,
          lifecycle_state: :submitted,
          score: 1.0,
          out_of: 1.0
        )

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      first_attempt
      |> ResourceAttempt.changeset(%{lifecycle_state: :evaluated})
      |> Repo.update!()

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(first_attempt.id)
      assert Repo.one!(AcceptedReward).resource_attempt_id == first_attempt.id
    end

    test "later attempts and reevaluation cannot replace an accepted reward" do
      context = setup_context(score: 1.0, out_of: 1.0)
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      context.resource_attempt
      |> ResourceAttempt.changeset(%{score: 0.0})
      |> Repo.update!()

      later_attempt =
        insert(:resource_attempt,
          resource_access: context.resource_access,
          revision: context.page_revision,
          attempt_number: 2,
          lifecycle_state: :evaluated,
          score: 0.0,
          out_of: 1.0
        )

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(later_attempt.id)

      reward = Repo.one!(AcceptedReward)
      assert reward.resource_attempt_id == context.resource_attempt.id
      assert reward.reward == 1
      assert Repo.get!(PolicyState, context.policy_state.id).reward_success_count == 1
    end

    test "replayed work returns without a second claim or posterior update" do
      context = setup_context(score: 1.0, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      assert Repo.aggregate(AcceptedReward, :count) == 1
      policy_state = Repo.get!(PolicyState, context.policy_state.id)
      assert policy_state.reward_success_count == 1
      assert policy_state.state["condition-a"]["successes"] == 1
    end

    test "makes accepted reward evidence available to the authoritative page snapshot" do
      context = setup_context(score: 1.0, out_of: 1.0, threshold: "0.75")

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      xapi_context = %Context{
        host_name: "https://example.edu",
        user_id: context.assignment.user_id,
        section_id: context.section.id,
        enrollment_id: context.assignment.enrollment_id,
        project_id: context.experiment.project_id,
        publication_id: context.publication.id
      }

      attempt_group = %AttemptGroup{
        context: xapi_context,
        part_attempts: [],
        activity_attempts: [],
        resource_attempt:
          Map.put(context.resource_attempt, :resource_id, context.resource_access.resource_id)
      }

      [statement] = StatementFactory.to_statements(attempt_group)

      [attribution] =
        statement["context"]["extensions"][
          "http://oli.cmu.edu/extensions/experiment_attributions"
        ]

      assert attribution["experiment_uuid"] == context.experiment.uuid
      assert attribution["experiment_id"] == context.experiment.id
      assert attribution["publication_id"] == context.publication.id
      assert attribution["enrollment_id"] == context.assignment.enrollment_id
      assert attribution["algorithm"] == "thompson_sampling"
      assert attribution["policy_version"] == "thompson_sampling:v2"
    end

    test "snapshot processing accepts and emits one attributed assessment reward" do
      context = setup_context(score: 1.0, out_of: 1.0, threshold: "0.75")
      registration = Oli.Activities.get_registration_by_slug("oli_short_answer")

      activity_revision =
        insert(:revision,
          activity_type_id: registration.id,
          content: %{"authoring" => %{"parts" => []}}
        )

      activity_attempt =
        insert(:activity_attempt,
          resource_attempt: context.resource_attempt,
          revision: activity_revision,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0
        )

      part_attempt =
        insert(:part_attempt,
          activity_attempt: activity_attempt,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0,
          response: %{"input" => "answer"},
          date_evaluated: DateTime.utc_now()
        )

      parent = self()

      emit = fn bundle ->
        send(parent, {:snapshot_bundle, bundle})
        :ok
      end

      assert :ok =
               RewardHandoff.record_if_active_thompson(
                 context.resource_attempt.id,
                 context.section.id
               )

      assert :ok =
               SnapshotWorker.perform_now(
                 [part_attempt.attempt_guid],
                 context.section.slug,
                 emit
               )

      assert Repo.aggregate(AcceptedReward, :count) == 1

      policy_state = Repo.get!(PolicyState, context.policy_state.id)
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 0

      assert_receive {:snapshot_bundle, %StatementBundle{body: body}}

      page_attempts =
        body
        |> String.split("\n", trim: true)
        |> Enum.map(&Jason.decode!/1)
        |> Enum.filter(fn statement ->
          get_in(statement, ["object", "definition", "type"]) ==
            "http://oli.cmu.edu/extensions/page_attempt"
        end)

      assert [page_attempt] = page_attempts

      assert [attribution] =
               get_in(page_attempt, [
                 "context",
                 "extensions",
                 "http://oli.cmu.edu/extensions/experiment_attributions"
               ])

      assert attribution["attribution_type"] == "reward"
      assert attribution["reward_value"] == 1
      assert attribution["page_revision_id"] == context.resource_attempt.revision_id
    end

    test "concurrent replay serializes to one claim and one posterior update" do
      context = setup_context(score: 1.0, out_of: 1.0)
      parent = self()

      tasks =
        for _ <- 1..2 do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
          end)
        end

      assert Enum.map(tasks, &Task.await(&1, 5_000)) == [:ok, :ok]
      assert Repo.aggregate(AcceptedReward, :count) == 1
      assert Repo.get!(PolicyState, context.policy_state.id).reward_success_count == 1
    end

    test "concurrent distinct rewards preserve every posterior increment" do
      first = setup_context(score: 1.0, out_of: 1.0)
      second = add_distinct_reward_context(first, score: 0.0, out_of: 1.0)
      parent = self()

      tasks =
        for attempt <- [first.resource_attempt, second.resource_attempt] do
          Task.async(fn ->
            Ecto.Adapters.SQL.Sandbox.allow(Repo, parent, self())
            RewardHandoff.record_evaluated_resource_attempt(attempt.id)
          end)
        end

      assert Enum.map(tasks, &Task.await(&1, 5_000)) == [:ok, :ok]
      assert Repo.aggregate(AcceptedReward, :count) == 2

      policy_state = Repo.get!(PolicyState, first.policy_state.id)
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 1
      assert policy_state.state["condition-a"]["posterior_alpha"] == 2.0
      assert policy_state.state["condition-a"]["posterior_beta"] == 2.0
    end

    test "transaction failure rolls back both the reward claim and posterior mutation" do
      context = setup_context(score: 0.0, out_of: 1.0)
      original_state = context.policy_state.state
      invalid_state = put_in(original_state, ["condition-a", "successes"], -1)

      from(policy_state in PolicyState, where: policy_state.id == ^context.policy_state.id)
      |> Repo.update_all(set: [state: invalid_state])

      assert_raise MatchError, fn ->
        RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      end

      assert Repo.aggregate(AcceptedReward, :count) == 0
      policy_state = Repo.get!(PolicyState, context.policy_state.id)
      assert policy_state.state == invalid_state
      assert policy_state.reward_success_count == 0
      assert policy_state.reward_failure_count == 0
    end

    test "reward processing retry succeeds after a transient failure" do
      context = setup_context(score: 0.0, out_of: 1.0)
      valid_state = context.policy_state.state
      invalid_state = put_in(valid_state, ["condition-a", "successes"], -1)

      from(policy_state in PolicyState, where: policy_state.id == ^context.policy_state.id)
      |> Repo.update_all(set: [state: invalid_state])

      assert_raise MatchError, fn ->
        RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      end

      from(policy_state in PolicyState, where: policy_state.id == ^context.policy_state.id)
      |> Repo.update_all(set: [state: valid_state])

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      assert Repo.aggregate(AcceptedReward, :count) == 1
      assert Repo.get!(PolicyState, context.policy_state.id).reward_failure_count == 1
    end

    test "missing persisted assignment never creates a retroactive assignment" do
      context = setup_context(score: 1.0, out_of: 1.0, assignment?: false)
      parent = self()
      event = [:oli, :experiments, :delivery_reward, :skipped]
      handler_id = "missing-assignment-skip-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        event,
        fn _, measurements, metadata, _ ->
          send(parent, {:reward_skip, measurements, metadata})
        end,
        %{}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)
      assert Repo.aggregate(AcceptedReward, :count) == 0
      assert Repo.aggregate(Assignment, :count) == 0

      assert_receive {:reward_skip, %{count: 1},
                      %{
                        reason: :missing_assignment,
                        assessment_binding_id: binding_id,
                        resource_attempt_id: resource_attempt_id
                      }}

      assert binding_id == context.binding.id
      assert resource_attempt_id == context.resource_attempt.id
    end

    test "only committed rewards affect later sampling and never change existing assignments" do
      context = setup_context(score: 1.0, out_of: 1.0)
      assignment_condition_id = context.assignment.condition_id
      conditions = [context.condition, context.condition_b]

      sampler = fn alpha, _beta, condition_code ->
        case {condition_code, alpha > 1.0} do
          {"condition-a", true} -> 0.9
          {"condition-a", false} -> 0.1
          {"condition-b", _} -> 0.8
        end
      end

      {:ok, before_reward} =
        ThompsonSampling.assign(%{}, context.policy_state.state, %{
          conditions: conditions,
          beta_sampler: sampler
        })

      assert before_reward.condition_code == "condition-b"
      assert :ok = RewardHandoff.record_evaluated_resource_attempt(context.resource_attempt.id)

      committed_state = Repo.get!(PolicyState, context.policy_state.id).state

      {:ok, after_reward} =
        ThompsonSampling.assign(%{}, committed_state, %{
          conditions: conditions,
          beta_sampler: sampler
        })

      assert after_reward.condition_code == "condition-a"
      assert Repo.get!(Assignment, context.assignment.id).condition_id == assignment_condition_id
    end
  end

  defp setup_context(opts) do
    project = insert(:project)
    section = insert(:section, base_project: project)
    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)
    page_revision = insert(:revision, graded: true)

    publication = insert(:publication, project: project)

    insert(:section_project_publication,
      section: section,
      project: project,
      publication: publication
    )

    insert(:published_resource,
      publication: publication,
      resource: page_revision.resource,
      revision: page_revision
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
        attempt_number: Keyword.get(opts, :attempt_number, 1),
        lifecycle_state: :evaluated,
        score: Keyword.fetch!(opts, :score),
        out_of: Keyword.fetch!(opts, :out_of)
      )

    alternatives = insert(:revision)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        slug: "assessment-reward-#{System.unique_integer([:positive])}",
        name: "Assessment reward",
        state: :active,
        algorithm: :thompson_sampling,
        alternatives_resource_id: alternatives.resource_id
      })
      |> Repo.insert!()

    %ExperimentSection{}
    |> ExperimentSection.changeset(%{experiment_id: experiment.id, section_id: section.id})
    |> Repo.insert!()

    condition =
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: experiment.id,
        condition_code: "condition-a",
        option_id: "option-a",
        label: "Condition A",
        weight: 1.0,
        position: 0
      })
      |> Repo.insert!()

    condition_b =
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: experiment.id,
        condition_code: "condition-b",
        option_id: "option-b",
        label: "Condition B",
        weight: 1.0,
        position: 1
      })
      |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: experiment.id,
        page_resource_id: alternatives.resource_id,
        content_element_id: "placement-a"
      })
      |> Repo.insert!()

    binding =
      %AssessmentBinding{}
      |> AssessmentBinding.changeset(%{
        intervention_id: intervention.id,
        assessment_page_resource_id: page_revision.resource_id,
        reward_threshold: Keyword.get(opts, :threshold, "1.0")
      })
      |> Repo.insert!()

    policy_state =
      %PolicyState{}
      |> PolicyState.changeset(%{
        experiment_id: experiment.id,
        algorithm: :thompson_sampling,
        algorithm_version: "thompson_sampling:v2",
        state: %{
          "condition-a" => %{
            "prior_alpha" => 1.0,
            "prior_beta" => 1.0,
            "successes" => 0,
            "failures" => 0,
            "posterior_alpha" => 1.0,
            "posterior_beta" => 1.0
          },
          "condition-b" => %{
            "prior_alpha" => 1.0,
            "prior_beta" => 1.0,
            "successes" => 0,
            "failures" => 0,
            "posterior_alpha" => 1.0,
            "posterior_beta" => 1.0
          }
        },
        prior_config: %{},
        reward_success_count: 0,
        reward_failure_count: 0,
        assignment_count: 0
      })
      |> Repo.insert!()

    assignment =
      case Keyword.get(opts, :assignment?, true) do
        true ->
          %Assignment{}
          |> Assignment.changeset(%{
            experiment_id: experiment.id,
            condition_id: condition.id,
            intervention_id: intervention.id,
            section_id: section.id,
            enrollment_id: enrollment.id,
            user_id: user.id,
            assigned_by_policy: "thompson_sampling",
            policy_version: "thompson_sampling:v2",
            assignment_key: "assignment-#{System.unique_integer([:positive])}",
            assigned_at: DateTime.utc_now() |> DateTime.truncate(:second),
            runtime_event_state: %{}
          })
          |> Repo.insert!()

        false ->
          nil
      end

    %{
      assignment: assignment,
      binding: binding,
      condition: condition,
      condition_b: condition_b,
      decision_point: experiment,
      experiment: experiment,
      page_revision: page_revision,
      publication: publication,
      policy_state: policy_state,
      resource_access: resource_access,
      resource_attempt: resource_attempt,
      section: section
    }
  end

  defp add_distinct_reward_context(context, opts) do
    user = insert(:user)
    enrollment = insert(:enrollment, section: context.section, user: user)
    page_revision = insert(:revision, graded: true)

    insert(:published_resource,
      publication: context.publication,
      resource: page_revision.resource,
      revision: page_revision
    )

    resource_access =
      insert(:resource_access,
        section: context.section,
        user: user,
        resource: page_revision.resource
      )

    resource_attempt =
      insert(:resource_attempt,
        resource_access: resource_access,
        revision: page_revision,
        attempt_number: 1,
        lifecycle_state: :evaluated,
        score: Keyword.fetch!(opts, :score),
        out_of: Keyword.fetch!(opts, :out_of)
      )

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: context.experiment.id,
        page_resource_id: context.decision_point.alternatives_resource_id,
        content_element_id: "placement-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert!()

    binding =
      %AssessmentBinding{}
      |> AssessmentBinding.changeset(%{
        intervention_id: intervention.id,
        assessment_page_resource_id: page_revision.resource_id,
        reward_threshold: "1.0"
      })
      |> Repo.insert!()

    %Assignment{}
    |> Assignment.changeset(%{
      experiment_id: context.experiment.id,
      condition_id: context.condition.id,
      intervention_id: intervention.id,
      section_id: context.resource_access.section_id,
      enrollment_id: enrollment.id,
      user_id: user.id,
      assigned_by_policy: "thompson_sampling",
      policy_version: "thompson_sampling:v2",
      assignment_key: "assignment-#{System.unique_integer([:positive])}",
      assigned_at: DateTime.utc_now() |> DateTime.truncate(:second),
      runtime_event_state: %{}
    })
    |> Repo.insert!()

    %{binding: binding, resource_attempt: resource_attempt}
  end
end
