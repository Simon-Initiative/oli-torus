defmodule Oli.Experiments.PersistenceTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments.Schemas.{
    AcceptedReward,
    Assignment,
    AssessmentBinding,
    Condition,
    DecisionPoint,
    DecisionPointCondition,
    ExperimentDefinition,
    Intervention,
    PolicyState
  }

  @removed_tables ~w(
    experiment_exposures
    experiment_outcomes
    experiment_rewards
    experiment_policy_updates
  )

  describe "experiment definition changeset" do
    test "requires the owned definition fields and validates enums" do
      changeset = ExperimentDefinition.changeset(%ExperimentDefinition{}, %{})

      refute changeset.valid?
      assert %{project_id: ["can't be blank"]} = errors_on(changeset)

      changeset =
        ExperimentDefinition.changeset(%ExperimentDefinition{}, %{
          project_id: 1,
          slug: "ab-test",
          name: "A/B Test",
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
      project = insert(:project)

      definition =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(%{
          project_id: project.id,
          slug: "ab-test",
          name: "A/B Test",
          algorithm: :weighted_random
        })
        |> Repo.insert!()

      assert {:error, changeset} =
               %ExperimentDefinition{}
               |> ExperimentDefinition.changeset(%{
                 project_id: insert(:project).id,
                 slug: "different-slug",
                 name: "Different Experiment",
                 uuid: definition.uuid,
                 algorithm: :weighted_random
               })
               |> Repo.insert()

      assert %{uuid: ["has already been taken"]} = errors_on(changeset)

      assert {:error, changeset} =
               %ExperimentDefinition{}
               |> ExperimentDefinition.changeset(%{
                 project_id: project.id,
                 slug: definition.slug,
                 name: "Duplicate Slug",
                 algorithm: :weighted_random
               })
               |> Repo.insert()

      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "experiment-scoped arm changesets" do
    test "enforces mapping bijection and intervention identity constraint names" do
      mapping =
        DecisionPointCondition.changeset(%DecisionPointCondition{}, %{
          decision_point_id: 1,
          condition_id: 2,
          option_id: "control",
          weight: 1.0,
          position: 0
        })

      intervention =
        Intervention.changeset(%Intervention{}, %{
          decision_point_id: 1,
          page_resource_id: 2,
          content_element_id: "placement-1"
        })

      assert mapping.valid?
      assert intervention.valid?

      assert Enum.any?(
               mapping.constraints,
               &(&1.constraint == "experiment_decision_point_conditions_condition_idx")
             )

      assert Enum.any?(
               mapping.constraints,
               &(&1.constraint == "experiment_decision_point_conditions_option_idx")
             )

      assert Enum.any?(
               intervention.constraints,
               &(&1.constraint == "experiment_interventions_identity_idx")
             )
    end

    test "validates assessment thresholds and accepted reward values" do
      binding =
        AssessmentBinding.changeset(%AssessmentBinding{}, %{
          intervention_id: 1,
          assessment_page_resource_id: 2,
          reward_threshold: Decimal.new("1.01")
        })

      reward =
        AcceptedReward.changeset(%AcceptedReward{}, %{
          assessment_binding_id: 1,
          assignment_id: 2,
          enrollment_id: 3,
          resource_attempt_id: 4,
          reward: 2,
          normalized_score: Decimal.new("0.5")
        })

      assert %{reward_threshold: ["must be less than or equal to 1"]} = errors_on(binding)
      assert %{reward: ["is invalid"]} = errors_on(reward)

      above_range =
        AcceptedReward.changeset(%AcceptedReward{}, %{
          assessment_binding_id: 1,
          assignment_id: 2,
          enrollment_id: 3,
          resource_attempt_id: 4,
          reward: 1,
          normalized_score: Decimal.new("1.01")
        })

      assert %{normalized_score: ["must be less than or equal to 1"]} =
               errors_on(above_range)
    end
  end

  describe "retained runtime persistence" do
    test "persists definition graph, assignment runtime state, and policy state" do
      project = insert(:project)
      section = insert(:section, base_project: project)
      user = insert(:user)
      enrollment = insert(:enrollment, section: section, user: user)
      revision = insert(:revision)

      definition =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(%{
          project_id: project.id,
          section_id: section.id,
          slug: "retained-runtime",
          name: "Retained runtime",
          algorithm: :thompson_sampling
        })
        |> Repo.insert!()

      decision_point =
        %DecisionPoint{}
        |> DecisionPoint.changeset(%{
          experiment_id: definition.id,
          alternatives_resource_id: revision.resource_id,
          decision_point_key: "alternatives:#{revision.resource_id}"
        })
        |> Repo.insert!()

      condition =
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: definition.id,
          decision_point_id: decision_point.id,
          condition_code: "a",
          label: "A",
          weight: 1.0
        })
        |> Repo.insert!()

      assignment =
        %Assignment{}
        |> Assignment.changeset(%{
          experiment_id: definition.id,
          decision_point_id: decision_point.id,
          condition_id: condition.id,
          section_id: section.id,
          enrollment_id: enrollment.id,
          user_id: user.id,
          assigned_by_policy: "weighted_random",
          policy_version: "v1",
          assignment_key: "assignment:#{System.unique_integer([:positive])}",
          assigned_at: DateTime.utc_now() |> DateTime.truncate(:second),
          runtime_event_state: %{
            "rewards" => %{"reward-key" => %{"id" => 2}}
          }
        })
        |> Repo.insert!()

      policy_state =
        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: definition.id,
          decision_point_id: decision_point.id,
          algorithm: :thompson_sampling,
          algorithm_version: "thompson_sampling:v2",
          state: %{},
          reward_success_count: 1,
          reward_failure_count: 0,
          assignment_count: 1
        })
        |> Repo.insert!()

      assert assignment.runtime_event_state["rewards"]["reward-key"]["id"] == 2
      assert policy_state.reward_success_count == 1
    end

    test "final native experiment migration does not create event-history tables" do
      migration =
        File.read!("priv/repo/migrations/20260625120000_create_experiment_tables.exs")

      for table <- @removed_tables do
        refute migration =~ "create table(:#{table})"
        refute migration =~ "references(:#{table}"
      end
    end
  end
end
