defmodule Oli.Experiments.PersistenceTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query

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
    test "persists assignment scope defaults and database constraints" do
      assert "assignment_scope" in columns_for("experiment_definitions")
      assert "assignment_scope" in columns_for("experiment_assignments")

      assert "experiment_definitions_assignment_scope_check" in constraints_for(
               "experiment_definitions"
             )

      assert "experiment_definitions_algorithm_assignment_scope_check" in constraints_for(
               "experiment_definitions"
             )

      assignment_constraints = constraints_for("experiment_assignments")
      assert "experiment_assignments_assignment_scope_check" in assignment_constraints
      assert "experiment_assignments_scope_identity_check" in assignment_constraints
      assert "experiment_assignments_experiment_scope_fkey" in assignment_constraints

      assert "experiment_assignments_section_enrollment_sticky_idx" in indexes_for(
               "experiment_assignments"
             )

      assert "experiment_assignments_intervention_lookup_idx" in indexes_for(
               "experiment_assignments"
             )
    end

    test "restricts Thompson Sampling definitions to intervention scope" do
      project = insert(:project)
      alternatives = insert(:revision)

      assert {:error, changeset} =
               %ExperimentDefinition{}
               |> ExperimentDefinition.changeset(%{
                 project_id: project.id,
                 alternatives_resource_id: alternatives.resource_id,
                 slug: "invalid-thompson-scope",
                 name: "Invalid Thompson scope",
                 algorithm: :thompson_sampling,
                 assignment_scope: :section_enrollment
               })
               |> Repo.insert()

      assert "section-and-enrollment scope is available only for weighted random experiments" in errors_on(
               changeset
             ).assignment_scope
    end

    test "supports both assignment identity shapes and enforces their uniqueness independently" do
      fixture = singular_experiment_fixture("intervention-assignment-scope")

      canonical_fixture =
        singular_experiment_fixture("canonical-assignment-scope", :section_enrollment)

      section = insert(:section, base_project: fixture.project)
      first_user = insert(:user)
      first_enrollment = insert(:enrollment, section: section, user: first_user)
      second_user = insert(:user)
      second_enrollment = insert(:enrollment, section: section, user: second_user)
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      intervention_assignment =
        assignment_attrs(fixture, section, first_enrollment, first_user, now)
        |> then(&Assignment.changeset(%Assignment{}, &1))
        |> Repo.insert!()

      assert intervention_assignment.assignment_scope == :intervention

      canonical_attrs =
        assignment_attrs(canonical_fixture, section, second_enrollment, second_user, now)
        |> Map.merge(%{
          intervention_id: nil,
          assignment_scope: :section_enrollment,
          assignment_key: "canonical-assignment"
        })

      canonical_assignment =
        %Assignment{}
        |> Assignment.changeset(canonical_attrs)
        |> Repo.insert!()

      assert canonical_assignment.intervention_id == nil
      assert canonical_assignment.assignment_scope == :section_enrollment

      assert {:error, duplicate_changeset} =
               %Assignment{}
               |> Assignment.changeset(%{canonical_attrs | assignment_key: "canonical-duplicate"})
               |> Repo.insert()

      assert "has already been taken" in errors_on(duplicate_changeset).experiment_id

      assert {:error, invalid_shape_changeset} =
               %Assignment{}
               |> Assignment.changeset(%{
                 canonical_attrs
                 | enrollment_id: first_enrollment.id,
                   user_id: first_user.id,
                   assignment_key: "invalid-shape",
                   intervention_id: canonical_fixture.intervention.id
               })
               |> Repo.insert()

      assert "must match the configured assignment scope" in errors_on(invalid_shape_changeset).intervention_id

      mismatched_scope_attrs =
        assignment_attrs(fixture, section, second_enrollment, second_user, now)
        |> Map.merge(%{
          intervention_id: nil,
          assignment_scope: :section_enrollment,
          assignment_key: "mismatched-experiment-scope"
        })

      assert {:error, mismatched_scope_changeset} =
               %Assignment{}
               |> Assignment.changeset(mismatched_scope_attrs)
               |> Repo.insert()

      assert "does not match the experiment assignment scope" in errors_on(
               mismatched_scope_changeset
             ).assignment_scope

      concurrent_user = insert(:user)
      concurrent_enrollment = insert(:enrollment, section: section, user: concurrent_user)

      concurrent_attrs =
        assignment_attrs(
          canonical_fixture,
          section,
          concurrent_enrollment,
          concurrent_user,
          now
        )
        |> Map.merge(%{intervention_id: nil, assignment_scope: :section_enrollment})

      concurrent_results =
        1..2
        |> Enum.map(fn suffix ->
          Task.async(fn ->
            %Assignment{}
            |> Assignment.changeset(%{
              concurrent_attrs
              | assignment_key: "concurrent-canonical-#{suffix}"
            })
            |> Repo.insert()
          end)
        end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.count(concurrent_results, &match?({:ok, %Assignment{}}, &1)) == 1
      assert Enum.count(concurrent_results, &match?({:error, %Ecto.Changeset{}}, &1)) == 1

      assert Repo.aggregate(
               from(assignment in Assignment,
                 where:
                   assignment.experiment_id == ^canonical_fixture.experiment.id and
                     assignment.section_id == ^section.id and
                     assignment.enrollment_id == ^concurrent_enrollment.id
               ),
               :count,
               :id
             ) == 1

      migration =
        File.read!("priv/repo/migrations/20260814143803_add_weighted_random_assignment_scope.exs")

      rollback_guard =
        ~r/execute """\n(?<sql>.*?)\n    """/s
        |> Regex.scan(migration, capture: :all_names)
        |> List.flatten()
        |> Enum.find(&String.contains?(&1, "cannot roll back assignment scope"))

      assert {:error, :expected_rollback_guard} =
               Repo.transaction(fn ->
                 assert_raise Postgrex.Error, ~r/cannot roll back assignment scope/, fn ->
                   Repo.query!(rollback_guard)
                 end

                 Repo.rollback(:expected_rollback_guard)
               end)
    end

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

    test "defines reversible ClickHouse assignment scope with an old-evidence default" do
      migration =
        File.read!(
          "priv/clickhouse/migrations/20260814120000_add_experiment_assignment_scope.sql"
        )

      assert migration =~ "-- +goose Up"

      assert migration =~
               "ADD COLUMN IF NOT EXISTS assignment_scope LowCardinality(String) DEFAULT 'intervention'"

      assert migration =~ "-- +goose Down"
      assert migration =~ "DROP COLUMN IF EXISTS assignment_scope;"
      refute migration =~ "StatementBegin"
    end
  end

  defp singular_experiment_fixture(suffix, assignment_scope \\ :intervention) do
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
        algorithm: :weighted_random,
        assignment_scope: assignment_scope
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

  defp assignment_attrs(fixture, section, enrollment, user, now) do
    %{
      experiment_id: fixture.experiment.id,
      condition_id: fixture.condition.id,
      intervention_id: fixture.intervention.id,
      section_id: section.id,
      enrollment_id: enrollment.id,
      user_id: user.id,
      assigned_by_policy: "weighted_random",
      assignment_key: "assignment-#{System.unique_integer([:positive])}",
      assigned_at: now
    }
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
