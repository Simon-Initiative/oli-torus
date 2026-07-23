defmodule Oli.Delivery.Experiments.RewardHandoffTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Analytics.Summary.AttemptGroup
  alias Oli.Analytics.XAPI.Events.Context
  alias Oli.Analytics.XAPI.StatementFactory
  alias Oli.Delivery.Experiments.RewardHandoff
  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAccess, ResourceAttempt}
  alias Oli.Experiments
  alias Oli.Experiments.{CreateExperimentRequest, LifecycleRequest, Scope}
  alias Oli.Resources.Revision

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    PolicyState
  }

  alias Oli.Resources.ResourceType

  describe "record_evaluated_activity/1" do
    test "records full-credit outcome and reward value 1.0" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 1.0, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      reward = only_event("rewards")

      assert event_count("outcomes") == 0
      assert is_integer(reward["outcome_id"])
      assert reward["reward_value"] == 1.0
      assert reward["reward_source"] == "activity_attempt:full_credit"
    end

    test "attaches outcome, reward, and rollup attributions to evaluated attempt xAPI" do
      %{activity_attempt: activity_attempt, scope: scope} =
        setup_reward_context(score: 1.0, out_of: 1.0)

      part_attempt =
        insert(:part_attempt,
          activity_attempt: activity_attempt,
          lifecycle_state: :evaluated,
          score: 1.0,
          out_of: 1.0,
          date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
        )

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      activity_revision = Repo.get!(Revision, activity_attempt.revision_id)
      resource_attempt = Repo.get!(ResourceAttempt, activity_attempt.resource_attempt_id)
      resource_access = Repo.get!(ResourceAccess, resource_attempt.resource_access_id)

      part_attempt =
        Map.merge(part_attempt, %{
          activity_attempt: activity_attempt,
          activity_revision: activity_revision
        })

      attempt_group = %AttemptGroup{
        context: %Context{
          host_name: "http://example.edu",
          user_id: scope.user_id,
          section_id: scope.section_id,
          project_id: scope.project_id,
          publication_id: scope.publication_id
        },
        part_attempts: [part_attempt],
        activity_attempts: [activity_attempt],
        resource_attempt:
          resource_attempt
          |> Map.put(:resource_id, resource_access.resource_id)
          |> Map.merge(%{
            lifecycle_state: :evaluated,
            score: 1.0,
            out_of: 1.0,
            date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
          })
      }

      statements = StatementFactory.to_statements(attempt_group)

      part_attributions =
        statements
        |> statement_by_object_type("http://adlnet.gov/expapi/activities/question")
        |> experiment_attributions()

      activity_attributions =
        statements
        |> statement_by_object_type("http://oli.cmu.edu/extensions/activity_attempt")
        |> experiment_attributions()

      page_attributions =
        statements
        |> statement_by_object_type("http://oli.cmu.edu/extensions/page_attempt")
        |> experiment_attributions()

      assert Enum.map(part_attributions, & &1["role"]) == ["outcome", "reward"]
      assert Enum.map(activity_attributions, & &1["role"]) == ["rollup", "rollup"]
      assert Enum.map(page_attributions, & &1["role"]) == ["rollup", "rollup"]

      for attributions <- [part_attributions, activity_attributions, page_attributions] do
        assert Enum.all?(attributions, &(&1["assignment_id"] != nil))
        assert Enum.all?(attributions, &(&1["experiment_id"] != nil))
      end
    end

    test "records non-full-credit reward value 0.0" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 0.5, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert only_event("rewards")["reward_value"] == 0.0
    end

    test "accepts activity attempt guids for bulk/finalization handoff paths" do
      %{activity_attempt: activity_attempt} = setup_reward_context(score: 1.0, out_of: 1.0)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.attempt_guid)

      assert event_count("outcomes") == 0
      assert event_count("rewards") == 1
    end

    test "reprocessing an evaluated attempt reuses reward idempotently" do
      %{activity_attempt: activity_attempt} =
        setup_reward_context(score: 1.0, out_of: 1.0, algorithm: :thompson_sampling)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)
      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert event_count("outcomes") == 0
      assert event_count("rewards") == 1
    end

    test "records Thompson reward for institutionless open and free sections" do
      %{activity_attempt: activity_attempt} =
        setup_reward_context(
          score: 1.0,
          out_of: 1.0,
          algorithm: :thompson_sampling,
          open_and_free?: true
        )

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert event_count("outcomes") == 0
      assert event_count("rewards") == 1
    end

    test "records one Thompson reward per evaluated activity in an unscored alternatives branch" do
      %{activity_attempts: [correct_attempt, incorrect_attempt]} =
        setup_reward_context(
          algorithm: :thompson_sampling,
          activity_scores: [{1.0, 1.0}, {0.0, 1.0}]
        )

      assert :ok = RewardHandoff.record_evaluated_activity(correct_attempt.id)
      assert :ok = RewardHandoff.record_evaluated_activity(incorrect_attempt.id)

      assert event_count("outcomes") == 0
      assert event_count("rewards") == 2

      policy_state = Repo.one!(PolicyState)
      assert policy_state.reward_success_count == 1
      assert policy_state.reward_failure_count == 1
      assert policy_state.state["condition-a"]["successes"] == 1
      assert policy_state.state["condition-a"]["failures"] == 1
      assert policy_state.state["condition-a"]["posterior_alpha"] == 2.0
      assert policy_state.state["condition-a"]["posterior_beta"] == 2.0
    end

    test "returns ok without records when no experiment assignment is eligible" do
      %{activity_attempt: activity_attempt} = setup_reward_context(assign?: false)

      assert :ok = RewardHandoff.record_evaluated_activity(activity_attempt.id)

      assert event_count("outcomes") == 0
      assert event_count("rewards") == 0
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
    activity_scores = Keyword.get(opts, :activity_scores, [{score, out_of}])
    assign? = Keyword.get(opts, :assign?, true)
    algorithm = Keyword.get(opts, :algorithm, :weighted_random)
    lifecycle_state = Keyword.get(opts, :lifecycle_state, :evaluated)
    open_and_free? = Keyword.get(opts, :open_and_free?, false)

    institution = insert(:institution)
    project = insert(:project)
    publication = insert(:publication, project: project)

    section =
      if open_and_free? do
        insert(:section, institution: nil, base_project: project, has_experiments: true)
      else
        insert(:section, institution: institution, base_project: project, has_experiments: true)
      end

    user = insert(:user)
    enrollment = insert(:enrollment, section: section, user: user)

    alternatives_revision = insert(:revision)

    activity_revisions =
      Enum.map(activity_scores, fn _score ->
        insert(:revision, resource_type_id: ResourceType.id_for_activity())
      end)

    page_revision =
      insert(:revision,
        resource_type_id: ResourceType.id_for_page(),
        graded: false,
        content:
          page_content(
            alternatives_revision.resource_id,
            Enum.map(activity_revisions, & &1.resource_id)
          )
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

    activity_attempts =
      activity_revisions
      |> Enum.zip(activity_scores)
      |> Enum.map(fn {activity_revision, {score, out_of}} ->
        insert(:activity_attempt,
          resource_attempt: resource_attempt,
          revision: activity_revision,
          resource: activity_revision.resource,
          lifecycle_state: lifecycle_state,
          score: score,
          out_of: out_of,
          date_evaluated: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      end)

    activity_attempt = List.first(activity_attempts)

    scope = %Scope{
      institution_id: if(open_and_free?, do: nil, else: institution.id),
      project_id: project.id,
      publication_id: publication.id,
      section_id: section.id,
      user_id: user.id,
      enrollment_id: enrollment.id
    }

    if assign? do
      create_assignment(scope, alternatives_revision, algorithm)
    end

    %{activity_attempt: activity_attempt, activity_attempts: activity_attempts, scope: scope}
  end

  defp create_assignment(%Scope{} = scope, alternatives_revision, algorithm) do
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

    {:ok, _assignment} =
      Experiments.assign_condition(%Oli.Experiments.AssignConditionRequest{
        scope: scope,
        alternatives_resource_id: alternatives_revision.resource_id,
        alternatives_revision_id: alternatives_revision.id,
        decision_point_key: "alternatives:#{alternatives_revision.resource_id}",
        available_condition_codes: ["condition-a"]
      })
  end

  defp page_content(alternatives_resource_id, activity_resource_ids) do
    %{
      "model" => [
        %{
          "type" => "alternatives",
          "alternatives_id" => alternatives_resource_id,
          "children" => [
            %{
              "type" => "alternative",
              "value" => "alt-a",
              "children" =>
                Enum.map(activity_resource_ids, fn activity_resource_id ->
                  %{
                    "type" => "activity-reference",
                    "activity_id" => activity_resource_id,
                    "children" => []
                  }
                end)
            },
            %{"type" => "alternative", "value" => "alt-b", "children" => []}
          ]
        }
      ]
    }
  end

  defp event_count(event_group) do
    Assignment
    |> Repo.all()
    |> Enum.reduce(0, fn assignment, total ->
      total + map_size(Map.get(assignment.runtime_event_state || %{}, event_group, %{}))
    end)
  end

  defp only_event(event_group) do
    [event] =
      Assignment
      |> Repo.all()
      |> Enum.flat_map(fn assignment ->
        assignment.runtime_event_state
        |> Kernel.||(%{})
        |> Map.get(event_group, %{})
        |> Map.values()
      end)

    event
  end

  defp statement_by_object_type(statements, object_type) do
    Enum.find(statements, fn statement ->
      get_in(statement, ["object", "definition", "type"]) == object_type
    end)
  end

  defp experiment_attributions(statement) do
    get_in(statement, [
      "context",
      "extensions",
      "http://oli.cmu.edu/extensions/experiment_attributions"
    ])
  end
end
