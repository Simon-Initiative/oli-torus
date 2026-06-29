defmodule Oli.Repo.Migrations.CreateExperimentTables do
  use Ecto.Migration

  @experiment_states ~w(draft active paused completed archived)
  @assignment_units ~w(enrollment)
  @algorithms ~w(weighted_random thompson_sampling)

  def change do
    create table(:experiment_definitions) do
      add :uuid, :uuid, null: false
      add :institution_id, references(:institutions, on_delete: :nothing), null: false
      add :project_id, references(:projects, on_delete: :nothing), null: false
      add :publication_id, references(:publications, on_delete: :nothing)
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

    create index(:experiment_definitions, [:institution_id])
    create index(:experiment_definitions, [:project_id])
    create index(:experiment_definitions, [:publication_id])
    create index(:experiment_definitions, [:section_id])
    create index(:experiment_definitions, [:state])

    create index(:experiment_definitions, [:institution_id, :project_id, :state],
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
      add :institution_id, references(:institutions, on_delete: :nothing), null: false
      add :section_id, references(:sections, on_delete: :nothing), null: false
      add :enrollment_id, references(:enrollments, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :publication_id, references(:publications, on_delete: :nothing)
      add :assigned_by_policy, :string, null: false
      add :policy_version, :string
      add :assignment_key, :string, null: false
      add :assigned_at, :utc_datetime, null: false

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
    create index(:experiment_assignments, [:publication_id])

    create table(:experiment_exposures) do
      add :assignment_id, references(:experiment_assignments, on_delete: :nothing), null: false
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :condition_id, references(:experiment_conditions, on_delete: :nothing), null: false
      add :section_id, references(:sections, on_delete: :nothing), null: false
      add :enrollment_id, references(:enrollments, on_delete: :nothing), null: false
      add :user_id, references(:users, on_delete: :nothing), null: false
      add :publication_id, references(:publications, on_delete: :nothing)
      add :content_revision_id, references(:revisions, on_delete: :nothing), null: false
      add :exposed_at, :utc_datetime, null: false
      add :idempotency_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiment_exposures, [:idempotency_key],
             name: :experiment_exposures_idempotency_idx
           )

    create index(:experiment_exposures, [:assignment_id])
    create index(:experiment_exposures, [:experiment_id])
    create index(:experiment_exposures, [:decision_point_id])
    create index(:experiment_exposures, [:section_id])
    create index(:experiment_exposures, [:enrollment_id])

    create table(:experiment_outcomes) do
      add :assignment_id, references(:experiment_assignments, on_delete: :nothing), null: false
      add :activity_attempt_id, references(:activity_attempts, on_delete: :nothing)
      add :resource_attempt_id, references(:resource_attempts, on_delete: :nothing)
      add :activity_resource_id, references(:resources, on_delete: :nothing)
      add :score, :float
      add :out_of, :float
      add :metadata, :map, null: false, default: %{}
      add :observed_at, :utc_datetime, null: false
      add :idempotency_key, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiment_outcomes, [:idempotency_key],
             name: :experiment_outcomes_idempotency_idx
           )

    create index(:experiment_outcomes, [:assignment_id])
    create index(:experiment_outcomes, [:activity_attempt_id])
    create index(:experiment_outcomes, [:resource_attempt_id])

    create table(:experiment_rewards) do
      add :assignment_id, references(:experiment_assignments, on_delete: :nothing), null: false
      add :outcome_id, references(:experiment_outcomes, on_delete: :nothing)
      add :experiment_id, references(:experiment_definitions, on_delete: :nothing), null: false

      add :decision_point_id, references(:experiment_decision_points, on_delete: :nothing),
        null: false

      add :condition_id, references(:experiment_conditions, on_delete: :nothing), null: false
      add :reward_value, :float, null: false
      add :reward_source, :string, null: false
      add :processed_at, :utc_datetime
      add :idempotency_key, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiment_rewards, [:idempotency_key],
             name: :experiment_rewards_idempotency_idx
           )

    create index(:experiment_rewards, [:assignment_id])
    create index(:experiment_rewards, [:experiment_id])
    create index(:experiment_rewards, [:decision_point_id])
    create index(:experiment_rewards, [:condition_id])

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
      add :last_updated_from_reward_id, references(:experiment_rewards, on_delete: :nothing)

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

    create index(:experiment_policy_states, [:last_updated_from_reward_id])

    create table(:experiment_policy_updates) do
      add :policy_state_id, references(:experiment_policy_states, on_delete: :nothing),
        null: false

      add :reward_id, references(:experiment_rewards, on_delete: :nothing), null: false
      add :condition_id, references(:experiment_conditions, on_delete: :nothing), null: false
      add :previous_state, :map, null: false, default: %{}
      add :next_state, :map, null: false, default: %{}
      add :algorithm_version, :string, null: false
      add :update_reason, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:experiment_policy_updates, [:reward_id],
             name: :experiment_policy_updates_reward_idx
           )

    create index(:experiment_policy_updates, [:policy_state_id])
    create index(:experiment_policy_updates, [:condition_id])
  end
end
