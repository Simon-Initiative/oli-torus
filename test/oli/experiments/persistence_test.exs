defmodule Oli.Experiments.PersistenceTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Experiments.Schemas.{
    Assignment,
    Condition,
    ExperimentDefinition,
    Intervention,
    PolicyState
  }

  @removed_tables ~w(
    experiment_decision_points
    experiment_decision_point_conditions
    experiment_exposures
    experiment_outcomes
    experiment_rewards
    experiment_policy_updates
  )

  @removed_decision_point_columns ~w(
    experiment_assignments
    experiment_conditions
    experiment_interventions
    experiment_policy_states
  )

  describe "singular experiment schema" do
    test "places group and policy ownership directly on the experiment" do
      columns = columns_for("experiment_definitions")

      for column <- ~w(
            alternatives_resource_id
            algorithm
            prior_alpha
            prior_beta
            warm_up_assignments
            max_condition_share
            fixed_control_allocation
            imbalance_threshold
            reward_source
          ) do
        assert column in columns
      end

      indexes = indexes_for("experiment_definitions")
      assert "experiment_definitions_active_alternatives_idx" in indexes
      assert "experiment_definitions_group_lookup_idx" in indexes
    end

    test "removes the decision-point hierarchy and all decision-point foreign keys" do
      tables =
        Repo.query!(
          "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'",
          []
        ).rows
        |> List.flatten()

      for table <- @removed_tables do
        refute table in tables
      end

      for table <- @removed_decision_point_columns do
        refute "decision_point_id" in columns_for(table)
      end
    end

    test "installs final experiment-scoped identities and composite foreign keys" do
      assert "experiment_conditions_experiment_option_idx" in indexes_for("experiment_conditions")
      assert "experiment_interventions_identity_idx" in indexes_for("experiment_interventions")

      assert "experiment_assignments_intervention_sticky_idx" in indexes_for(
               "experiment_assignments"
             )

      assert "experiment_assignments_runtime_lookup_idx" in indexes_for("experiment_assignments")
      assert "experiment_policy_states_unique_idx" in indexes_for("experiment_policy_states")

      assignment_constraints = constraints_for("experiment_assignments")

      assert "experiment_assignments_intervention_experiment_fkey" in assignment_constraints
      assert "experiment_assignments_condition_experiment_fkey" in assignment_constraints
    end

    test "persists one experiment-owned mapping, intervention assignment, and policy state" do
      project = insert(:project)
      section = insert(:section, base_project: project)
      user = insert(:user)
      enrollment = insert(:enrollment, section: section, user: user)
      alternatives = insert(:revision)
      page = insert(:revision)

      experiment =
        %ExperimentDefinition{}
        |> ExperimentDefinition.changeset(%{
          project_id: project.id,
          alternatives_resource_id: alternatives.resource_id,
          slug: "singular-runtime",
          name: "Singular runtime",
          algorithm: :thompson_sampling
        })
        |> Repo.insert!()

      condition =
        %Condition{}
        |> Condition.changeset(%{
          experiment_id: experiment.id,
          condition_code: "control",
          option_id: "control-option",
          label: "Control",
          weight: 1.0
        })
        |> Repo.insert!()

      intervention =
        %Intervention{}
        |> Intervention.changeset(%{
          experiment_id: experiment.id,
          page_resource_id: page.resource_id,
          content_element_id: "placement-1"
        })
        |> Repo.insert!()

      assignment =
        %Assignment{}
        |> Assignment.changeset(%{
          experiment_id: experiment.id,
          condition_id: condition.id,
          intervention_id: intervention.id,
          section_id: section.id,
          enrollment_id: enrollment.id,
          user_id: user.id,
          assigned_by_policy: "thompson_sampling",
          policy_version: "v1",
          assignment_key: "assignment:#{System.unique_integer([:positive])}",
          assigned_at: DateTime.utc_now() |> DateTime.truncate(:second),
          runtime_event_state: %{"exposure" => "pending"}
        })
        |> Repo.insert!()

      policy_state =
        %PolicyState{}
        |> PolicyState.changeset(%{
          experiment_id: experiment.id,
          algorithm: :thompson_sampling,
          algorithm_version: "thompson_sampling:v2",
          state: %{"control" => %{"alpha" => 1.0, "beta" => 1.0}},
          reward_success_count: 0,
          reward_failure_count: 0,
          assignment_count: 1
        })
        |> Repo.insert!()

      assert assignment.intervention_id == intervention.id
      assert assignment.runtime_event_state == %{"exposure" => "pending"}
      assert policy_state.experiment_id == experiment.id
    end

    test "rejects cross-experiment assignment relationships" do
      first = singular_experiment_fixture("first")
      second = singular_experiment_fixture("second")
      section = insert(:section, base_project: first.project)
      user = insert(:user)
      enrollment = insert(:enrollment, section: section, user: user)

      assert {:error, changeset} =
               %Assignment{}
               |> Assignment.changeset(%{
                 experiment_id: first.experiment.id,
                 condition_id: first.condition.id,
                 intervention_id: second.intervention.id,
                 section_id: section.id,
                 enrollment_id: enrollment.id,
                 user_id: user.id,
                 assigned_by_policy: "weighted_random",
                 assignment_key: "cross-experiment",
                 assigned_at: DateTime.utc_now() |> DateTime.truncate(:second)
               })
               |> Repo.insert()

      assert "does not belong to the selected experiment" in errors_on(changeset).intervention_id
    end

    test "defines reversible ClickHouse decision-point removal as standalone statements" do
      migration =
        File.read!(
          "priv/clickhouse/migrations/20260813180000_remove_experiment_decision_point_attribution.sql"
        )

      assert migration =~ "-- +goose Up"
      assert migration =~ "DROP COLUMN IF EXISTS decision_point_id;"
      assert migration =~ "DROP COLUMN IF EXISTS decision_point_key;"
      assert migration =~ "-- +goose Down"
      assert migration =~ "ADD COLUMN IF NOT EXISTS decision_point_id Nullable(UInt64)"
      assert migration =~ "ADD COLUMN IF NOT EXISTS decision_point_key Nullable(String)"
      refute migration =~ "StatementBegin"
    end
  end

  defp singular_experiment_fixture(suffix) do
    project = insert(:project)
    alternatives = insert(:revision)
    page = insert(:revision)

    experiment =
      %ExperimentDefinition{}
      |> ExperimentDefinition.changeset(%{
        project_id: project.id,
        alternatives_resource_id: alternatives.resource_id,
        slug: "singular-#{suffix}",
        name: "Singular #{suffix}",
        algorithm: :weighted_random
      })
      |> Repo.insert!()

    condition =
      %Condition{}
      |> Condition.changeset(%{
        experiment_id: experiment.id,
        condition_code: "control",
        option_id: "control-option",
        label: "Control"
      })
      |> Repo.insert!()

    intervention =
      %Intervention{}
      |> Intervention.changeset(%{
        experiment_id: experiment.id,
        page_resource_id: page.resource_id,
        content_element_id: "placement-#{suffix}"
      })
      |> Repo.insert!()

    %{project: project, experiment: experiment, condition: condition, intervention: intervention}
  end

  defp columns_for(table) do
    Repo.query!(
      "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1",
      [table]
    ).rows
    |> List.flatten()
  end

  defp indexes_for(table) do
    Repo.query!(
      "SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename = $1",
      [table]
    ).rows
    |> List.flatten()
  end

  defp constraints_for(table) do
    Repo.query!(
      "SELECT constraint_name FROM information_schema.table_constraints WHERE table_schema = 'public' AND table_name = $1",
      [table]
    ).rows
    |> List.flatten()
  end
end
