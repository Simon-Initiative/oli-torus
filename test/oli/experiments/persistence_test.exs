defmodule Oli.Experiments.PersistenceTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    DecisionPoint,
    ExperimentDefinition,
    Exposure,
    Outcome,
    PolicyState,
    PolicyUpdate,
    Reward
  }

  describe "experiment definition changeset" do
    test "requires the owned definition fields and validates enums" do
      changeset = ExperimentDefinition.changeset(%ExperimentDefinition{}, %{})

      refute changeset.valid?

      assert %{project_id: ["can't be blank"], institution_id: ["can't be blank"]} =
               errors_on(changeset)

      changeset =
        ExperimentDefinition.changeset(%ExperimentDefinition{}, %{
          institution_id: 1,
          project_id: 1,
          slug: "native-ab-test",
          name: "Native A/B Test",
          state: :unknown,
          assignment_unit: :user,
          algorithm: :unsupported
        })

      refute changeset.valid?

      assert %{
               state: ["is invalid"],
               assignment_unit: ["is invalid"],
               algorithm: ["is invalid"]
             } = errors_on(changeset)
    end

    test "persists definition scope and prevents duplicate UUIDs and project slugs" do
      %{definition: definition, project: project} = insert_definition_graph()

      duplicate_uuid =
        %{
          institution_id: definition.institution_id,
          project_id: insert(:project).id,
          slug: "different-slug",
          name: "Different Experiment",
          uuid: definition.uuid,
          algorithm: :weighted_random
        }
        |> insert_definition()

      assert {:error, changeset} = duplicate_uuid
      assert %{uuid: ["has already been taken"]} = errors_on(changeset)

      duplicate_project_slug =
        %{
          institution_id: definition.institution_id,
          project_id: project.id,
          slug: definition.slug,
          name: "Duplicate Slug",
          algorithm: :weighted_random
        }
        |> insert_definition()

      assert {:error, changeset} = duplicate_project_slug
      assert %{project_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "private persistence graph" do
    test "persists every Phase 1 MVP record type through private changesets" do
      graph = insert_full_graph()

      assert %ExperimentDefinition{} = graph.definition
      assert %DecisionPoint{} = graph.decision_point
      assert %Condition{} = graph.condition
      assert %Assignment{} = graph.assignment
      assert %Exposure{} = graph.exposure
      assert %Outcome{} = graph.outcome
      assert %Reward{} = graph.reward
      assert %PolicyState{} = graph.policy_state
      assert %PolicyUpdate{} = graph.policy_update
    end

    test "prevents duplicate decision points, conditions, sticky assignments, and idempotency keys" do
      graph = insert_full_graph()

      assert {:error, changeset} =
               insert_decision_point(%{
                 experiment_id: graph.definition.id,
                 alternatives_resource_id: graph.revision.resource_id,
                 alternatives_revision_id: graph.revision.id,
                 decision_point_key: graph.decision_point.decision_point_key
               })

      assert %{experiment_id: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_condition(%{
                 experiment_id: graph.definition.id,
                 decision_point_id: graph.decision_point.id,
                 condition_code: graph.condition.condition_code
               })

      assert %{decision_point_id: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_assignment(%{
                 graph
                 | assignment_key: "another-key"
               })

      assert %{experiment_id: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_exposure(%{
                 graph
                 | idempotency_key: graph.exposure.idempotency_key
               })

      assert %{idempotency_key: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_outcome(%{
                 graph
                 | idempotency_key: graph.outcome.idempotency_key
               })

      assert %{idempotency_key: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_reward(%{
                 graph
                 | idempotency_key: graph.reward.idempotency_key
               })

      assert %{idempotency_key: ["has already been taken"]} = errors_on(changeset)
    end

    test "prevents duplicate policy state rows and reward policy updates" do
      graph = insert_full_graph()

      assert {:error, changeset} =
               insert_policy_state(%{
                 experiment_id: graph.definition.id,
                 decision_point_id: graph.decision_point.id,
                 algorithm: graph.policy_state.algorithm
               })

      assert %{experiment_id: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               insert_policy_update(%{
                 policy_state_id: graph.policy_state.id,
                 reward_id: graph.reward.id,
                 condition_id: graph.condition.id
               })

      assert %{reward_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates non-negative weights and policy counters before persistence" do
      condition =
        Condition.changeset(%Condition{}, %{
          experiment_id: 1,
          decision_point_id: 1,
          condition_code: "a",
          weight: -1
        })

      refute condition.valid?
      assert %{weight: ["must be greater than or equal to 0"]} = errors_on(condition)

      policy_state =
        PolicyState.changeset(%PolicyState{}, %{
          experiment_id: 1,
          decision_point_id: 1,
          algorithm: :weighted_random,
          algorithm_version: "v1",
          reward_success_count: -1,
          reward_failure_count: -1,
          assignment_count: -1
        })

      refute policy_state.valid?

      assert %{
               reward_success_count: ["must be greater than or equal to 0"],
               reward_failure_count: ["must be greater than or equal to 0"],
               assignment_count: ["must be greater than or equal to 0"]
             } = errors_on(policy_state)
    end
  end

  describe "ownership guardrail" do
    test "production modules outside Oli.Experiments do not reference private schemas" do
      references =
        "lib"
        |> Path.join("**/*.ex")
        |> Path.wildcard()
        |> Enum.reject(&String.starts_with?(&1, "lib/oli/experiments/"))
        |> Enum.flat_map(fn path ->
          path
          |> File.read!()
          |> then(fn content ->
            if String.contains?(content, "Oli.Experiments.Schemas"), do: [path], else: []
          end)
        end)

      assert references == []
    end
  end

  defp insert_definition_graph(attrs \\ %{}) do
    institution = Map.get_lazy(attrs, :institution, fn -> insert(:institution) end)
    project = Map.get_lazy(attrs, :project, fn -> insert(:project) end)
    section = Map.get_lazy(attrs, :section, fn -> insert(:section, institution: institution) end)

    publication =
      Map.get_lazy(attrs, :publication, fn -> insert(:publication, project: project) end)

    definition =
      attrs
      |> Map.take([:uuid, :slug, :name, :state, :assignment_unit, :algorithm, :policy_config])
      |> Map.merge(%{
        institution_id: institution.id,
        project_id: project.id,
        publication_id: publication.id,
        section_id: section.id
      })
      |> insert_definition!()

    %{
      institution: institution,
      project: project,
      section: section,
      publication: publication,
      definition: definition
    }
  end

  defp insert_full_graph do
    graph = insert_definition_graph()
    revision = insert(:revision)
    user = insert(:user)
    enrollment = insert(:enrollment, user: user, section: graph.section)

    decision_point =
      insert_decision_point!(%{
        experiment_id: graph.definition.id,
        alternatives_resource_id: revision.resource_id,
        alternatives_revision_id: revision.id,
        decision_point_key: "alternatives:#{revision.resource_id}",
        title: "Decision point"
      })

    condition =
      insert_condition!(%{
        experiment_id: graph.definition.id,
        decision_point_id: decision_point.id,
        condition_code: "a",
        option_id: "option-a",
        label: "A",
        weight: 1.0
      })

    assignment =
      insert_assignment!(%{
        definition: graph.definition,
        decision_point: decision_point,
        condition: condition,
        institution: graph.institution,
        section: graph.section,
        enrollment: enrollment,
        user: user,
        publication: graph.publication,
        assignment_key: "assignment:#{enrollment.id}"
      })

    exposure =
      insert_exposure!(%{
        assignment: assignment,
        definition: graph.definition,
        decision_point: decision_point,
        condition: condition,
        section: graph.section,
        enrollment: enrollment,
        user: user,
        publication: graph.publication,
        revision: revision,
        idempotency_key: "exposure:#{assignment.id}"
      })

    outcome =
      insert_outcome!(%{
        assignment: assignment,
        idempotency_key: "outcome:#{assignment.id}"
      })

    reward =
      insert_reward!(%{
        assignment: assignment,
        outcome: outcome,
        definition: graph.definition,
        decision_point: decision_point,
        condition: condition,
        idempotency_key: "reward:#{assignment.id}"
      })

    policy_state =
      insert_policy_state!(%{
        experiment_id: graph.definition.id,
        decision_point_id: decision_point.id,
        algorithm: :weighted_random
      })

    policy_update =
      insert_policy_update!(%{
        policy_state_id: policy_state.id,
        reward_id: reward.id,
        condition_id: condition.id
      })

    graph
    |> Map.merge(%{
      revision: revision,
      user: user,
      enrollment: enrollment,
      decision_point: decision_point,
      condition: condition,
      assignment: assignment,
      exposure: exposure,
      outcome: outcome,
      reward: reward,
      policy_state: policy_state,
      policy_update: policy_update
    })
  end

  defp insert_definition(attrs) do
    %ExperimentDefinition{}
    |> ExperimentDefinition.changeset(default_definition_attrs(attrs))
    |> Repo.insert()
  end

  defp insert_definition!(attrs) do
    %ExperimentDefinition{}
    |> ExperimentDefinition.changeset(default_definition_attrs(attrs))
    |> Repo.insert!()
  end

  defp default_definition_attrs(attrs) do
    Map.merge(
      %{
        slug: "experiment-#{System.unique_integer([:positive])}",
        name: "Experiment",
        state: :draft,
        assignment_unit: :enrollment,
        algorithm: :weighted_random,
        policy_config: %{}
      },
      attrs
    )
  end

  defp insert_decision_point(attrs) do
    %DecisionPoint{}
    |> DecisionPoint.changeset(default_decision_point_attrs(attrs))
    |> Repo.insert()
  end

  defp insert_decision_point!(attrs) do
    %DecisionPoint{}
    |> DecisionPoint.changeset(default_decision_point_attrs(attrs))
    |> Repo.insert!()
  end

  defp default_decision_point_attrs(attrs) do
    Map.merge(%{position: 0}, attrs)
  end

  defp insert_condition(attrs) do
    %Condition{}
    |> Condition.changeset(default_condition_attrs(attrs))
    |> Repo.insert()
  end

  defp insert_condition!(attrs) do
    %Condition{}
    |> Condition.changeset(default_condition_attrs(attrs))
    |> Repo.insert!()
  end

  defp default_condition_attrs(attrs) do
    Map.merge(%{condition_code: "condition-#{System.unique_integer([:positive])}"}, attrs)
  end

  defp insert_assignment(%{definition: definition} = graph) do
    graph
    |> assignment_attrs(definition)
    |> then(&Assignment.changeset(%Assignment{}, &1))
    |> Repo.insert()
  end

  defp insert_assignment!(%{definition: definition} = graph) do
    graph
    |> assignment_attrs(definition)
    |> then(&Assignment.changeset(%Assignment{}, &1))
    |> Repo.insert!()
  end

  defp assignment_attrs(graph, definition) do
    Map.merge(
      %{
        experiment_id: definition.id,
        decision_point_id: graph.decision_point.id,
        condition_id: graph.condition.id,
        institution_id: graph.institution.id,
        section_id: graph.section.id,
        enrollment_id: graph.enrollment.id,
        user_id: graph.user.id,
        publication_id: graph.publication.id,
        assigned_by_policy: "weighted_random",
        policy_version: "v1",
        assignment_key: "assignment:#{System.unique_integer([:positive])}",
        assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      Map.take(graph, [:assignment_key])
    )
  end

  defp insert_exposure(graph) do
    graph
    |> exposure_attrs()
    |> then(&Exposure.changeset(%Exposure{}, &1))
    |> Repo.insert()
  end

  defp insert_exposure!(graph) do
    graph
    |> exposure_attrs()
    |> then(&Exposure.changeset(%Exposure{}, &1))
    |> Repo.insert!()
  end

  defp exposure_attrs(graph) do
    Map.merge(
      %{
        assignment_id: graph.assignment.id,
        experiment_id: graph.definition.id,
        decision_point_id: graph.decision_point.id,
        condition_id: graph.condition.id,
        section_id: graph.section.id,
        enrollment_id: graph.enrollment.id,
        user_id: graph.user.id,
        publication_id: graph.publication.id,
        content_revision_id: graph.revision.id,
        exposed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        idempotency_key: "exposure:#{System.unique_integer([:positive])}"
      },
      Map.take(graph, [:idempotency_key])
    )
  end

  defp insert_outcome(graph) do
    graph
    |> outcome_attrs()
    |> then(&Outcome.changeset(%Outcome{}, &1))
    |> Repo.insert()
  end

  defp insert_outcome!(graph) do
    graph
    |> outcome_attrs()
    |> then(&Outcome.changeset(%Outcome{}, &1))
    |> Repo.insert!()
  end

  defp outcome_attrs(graph) do
    Map.merge(
      %{
        assignment_id: graph.assignment.id,
        score: 1.0,
        out_of: 1.0,
        metadata: %{},
        observed_at: DateTime.utc_now() |> DateTime.truncate(:second),
        idempotency_key: "outcome:#{System.unique_integer([:positive])}"
      },
      Map.take(graph, [:idempotency_key])
    )
  end

  defp insert_reward(graph) do
    graph
    |> reward_attrs()
    |> then(&Reward.changeset(%Reward{}, &1))
    |> Repo.insert()
  end

  defp insert_reward!(graph) do
    graph
    |> reward_attrs()
    |> then(&Reward.changeset(%Reward{}, &1))
    |> Repo.insert!()
  end

  defp reward_attrs(graph) do
    Map.merge(
      %{
        assignment_id: graph.assignment.id,
        outcome_id: graph.outcome.id,
        experiment_id: graph.definition.id,
        decision_point_id: graph.decision_point.id,
        condition_id: graph.condition.id,
        reward_value: 1.0,
        reward_source: "test",
        idempotency_key: "reward:#{System.unique_integer([:positive])}",
        metadata: %{}
      },
      Map.take(graph, [:idempotency_key])
    )
  end

  defp insert_policy_state(attrs) do
    %PolicyState{}
    |> PolicyState.changeset(default_policy_state_attrs(attrs))
    |> Repo.insert()
  end

  defp insert_policy_state!(attrs) do
    %PolicyState{}
    |> PolicyState.changeset(default_policy_state_attrs(attrs))
    |> Repo.insert!()
  end

  defp default_policy_state_attrs(attrs) do
    Map.merge(
      %{
        algorithm_version: "v1",
        state: %{},
        prior_config: %{},
        reward_success_count: 0,
        reward_failure_count: 0,
        assignment_count: 0
      },
      attrs
    )
  end

  defp insert_policy_update(attrs) do
    %PolicyUpdate{}
    |> PolicyUpdate.changeset(default_policy_update_attrs(attrs))
    |> Repo.insert()
  end

  defp insert_policy_update!(attrs) do
    %PolicyUpdate{}
    |> PolicyUpdate.changeset(default_policy_update_attrs(attrs))
    |> Repo.insert!()
  end

  defp default_policy_update_attrs(attrs) do
    Map.merge(
      %{
        previous_state: %{},
        next_state: %{"updated" => true},
        algorithm_version: "v1",
        update_reason: "reward"
      },
      attrs
    )
  end
end
