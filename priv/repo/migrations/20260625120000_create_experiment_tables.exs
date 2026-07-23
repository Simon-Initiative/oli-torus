defmodule Oli.Repo.Migrations.CreateExperimentTables do
  use Ecto.Migration

  @experiment_states ~w(draft active paused completed archived)
  @assignment_units ~w(enrollment)
  @algorithms ~w(weighted_random thompson_sampling)

  def up do
    create table(:experiment_definitions) do
      add :uuid, :uuid, null: false
      add :project_id, references(:projects, on_delete: :nothing), null: false
      add :section_id, references(:sections, on_delete: :nothing)
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :state, :string, null: false, default: "draft"
      add :assignment_unit, :string, null: false, default: "enrollment"
      add :algorithm, :string, null: false
      add :policy_config, :map, null: false, default: %{}
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create constraint(:experiment_definitions, :experiment_definitions_state_check,
             check: "state = ANY (ARRAY['#{Enum.join(@experiment_states, "', '")}'])"
           )

    create constraint(:experiment_definitions, :experiment_definitions_assignment_unit_check,
             check: "assignment_unit = ANY (ARRAY['#{Enum.join(@assignment_units, "', '")}'])"
           )

    create constraint(:experiment_definitions, :experiment_definitions_algorithm_check,
             check: "algorithm = ANY (ARRAY['#{Enum.join(@algorithms, "', '")}'])"
           )

    create unique_index(:experiment_definitions, [:uuid], name: :experiment_definitions_uuid_idx)

    create unique_index(:experiment_definitions, [:project_id, :slug],
             name: :experiment_definitions_project_slug_idx
           )

    create index(:experiment_definitions, [:project_id])
    create index(:experiment_definitions, [:section_id])
    create index(:experiment_definitions, [:state])

    create index(:experiment_definitions, [:project_id, :state],
             name: :experiment_definitions_active_scope_idx
           )

    create table(:experiment_decision_points) do
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false
      add :alternatives_resource_id, references(:resources, on_delete: :nothing), null: false
      add :alternatives_revision_id, references(:revisions, on_delete: :nothing), null: false
      add :decision_point_key, :string, null: false
      add :title, :string
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiment_decision_points, [:experiment_id, :decision_point_key],
             name: :experiment_decision_points_key_idx
           )

    create index(:experiment_decision_points, [:alternatives_resource_id])
    create index(:experiment_decision_points, [:alternatives_revision_id])

    create index(
             :experiment_decision_points,
             [:alternatives_resource_id, :alternatives_revision_id, :decision_point_key],
             name: :experiment_decision_points_lookup_idx
           )

    create table(:experiment_conditions) do
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :condition_code, :string, null: false
      add :option_id, :string
      add :label, :string
      add :weight, :float, null: false, default: 1.0
      add :active, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create constraint(:experiment_conditions, :experiment_conditions_weight_check,
             check: "weight >= 0"
           )

    create unique_index(:experiment_conditions, [:decision_point_id, :condition_code],
             name: :experiment_conditions_code_idx
           )

    create index(:experiment_conditions, [:experiment_id])
    create index(:experiment_conditions, [:active])

    create table(:experiment_assignments) do
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :condition_id, references(:experiment_conditions, on_delete: :nothing), null: false
      add :section_id, references(:sections, on_delete: :nothing), null: false
      add :enrollment_id, references(:enrollments, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :assigned_by_policy, :string, null: false
      add :policy_version, :string
      add :assignment_key, :string, null: false
      add :assigned_at, :utc_datetime, null: false
      add :runtime_event_state, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(
             :experiment_assignments,
             [:experiment_id, :decision_point_id, :enrollment_id],
             name: :experiment_assignments_sticky_idx
           )

    create unique_index(:experiment_assignments, [:assignment_key],
             name: :experiment_assignments_key_idx
           )

    create index(:experiment_assignments, [:condition_id])
    create index(:experiment_assignments, [:section_id])
    create index(:experiment_assignments, [:user_id])

    create table(:experiment_policy_states) do
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :algorithm, :string, null: false
      add :algorithm_version, :string, null: false
      add :state, :map, null: false, default: %{}
      add :prior_config, :map, null: false, default: %{}
      add :reward_success_count, :integer, null: false, default: 0
      add :reward_failure_count, :integer, null: false, default: 0
      add :assignment_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create constraint(:experiment_policy_states, :experiment_policy_states_algorithm_check,
             check: "algorithm = ANY (ARRAY['#{Enum.join(@algorithms, "', '")}'])"
           )

    create constraint(:experiment_policy_states, :experiment_policy_states_counts_check,
             check:
               "reward_success_count >= 0 AND reward_failure_count >= 0 AND assignment_count >= 0"
           )

    create unique_index(
             :experiment_policy_states,
             [:experiment_id, :decision_point_id, :algorithm],
             name: :experiment_policy_states_unique_idx
           )
  end

  def down do
    execute("DROP TABLE IF EXISTS experiment_policy_updates CASCADE")
    execute("DROP TABLE IF EXISTS experiment_rewards CASCADE")
    execute("DROP TABLE IF EXISTS experiment_outcomes CASCADE")
    execute("DROP TABLE IF EXISTS experiment_exposures CASCADE")

    drop table(:experiment_policy_states)
    drop table(:experiment_assignments)
    drop table(:experiment_conditions)
    drop table(:experiment_decision_points)
    drop table(:experiment_definitions)
  end
end
