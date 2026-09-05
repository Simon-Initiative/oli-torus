defmodule Oli.Repo.Migrations.AddWeightedRandomAssignmentScope do
  use Ecto.Migration

  def up do
    alter table(:experiment_definitions) do
      add :assignment_scope, :string, null: false, default: "intervention"
    end

    create constraint(:experiment_definitions, :experiment_definitions_assignment_scope_check,
             check: "assignment_scope IN ('intervention', 'section_enrollment')"
           )

    create constraint(
             :experiment_definitions,
             :experiment_definitions_algorithm_assignment_scope_check,
             check: "algorithm != 'thompson_sampling' OR assignment_scope = 'intervention'"
           )

    create unique_index(:experiment_definitions, [:id, :assignment_scope],
             name: :experiment_definitions_id_assignment_scope_idx
           )

    drop index(:experiment_assignments, [:intervention_id, :enrollment_id],
           name: :experiment_assignments_intervention_sticky_idx
         )

    alter table(:experiment_assignments) do
      add :assignment_scope, :string, null: false, default: "intervention"

      modify :intervention_id, references(:experiment_interventions, on_delete: :delete_all),
        null: true,
        from: references(:experiment_interventions, on_delete: :delete_all)
    end

    create constraint(:experiment_assignments, :experiment_assignments_assignment_scope_check,
             check: "assignment_scope IN ('intervention', 'section_enrollment')"
           )

    create constraint(:experiment_assignments, :experiment_assignments_scope_identity_check,
             check:
               "(assignment_scope = 'intervention' AND intervention_id IS NOT NULL) OR " <>
                 "(assignment_scope = 'section_enrollment' AND intervention_id IS NULL)"
           )

    execute """
    ALTER TABLE experiment_assignments
    ADD CONSTRAINT experiment_assignments_experiment_scope_fkey
    FOREIGN KEY (experiment_id, assignment_scope)
    REFERENCES experiment_definitions(id, assignment_scope)
    ON DELETE CASCADE
    """

    create unique_index(
             :experiment_assignments,
             [:experiment_id, :intervention_id, :enrollment_id],
             name: :experiment_assignments_intervention_sticky_idx,
             where: "assignment_scope = 'intervention'"
           )

    create index(:experiment_assignments, [:intervention_id, :enrollment_id],
             name: :experiment_assignments_intervention_lookup_idx
           )

    create unique_index(:experiment_assignments, [:experiment_id, :section_id, :enrollment_id],
             name: :experiment_assignments_section_enrollment_sticky_idx,
             where: "assignment_scope = 'section_enrollment'"
           )
  end

  def down do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM experiment_assignments WHERE assignment_scope = 'section_enrollment') THEN
        RAISE EXCEPTION 'cannot roll back assignment scope while section_enrollment assignments exist';
      END IF;
    END
    $$;
    """

    drop index(:experiment_assignments, [:experiment_id, :section_id, :enrollment_id],
           name: :experiment_assignments_section_enrollment_sticky_idx
         )

    drop index(:experiment_assignments, [:intervention_id, :enrollment_id],
           name: :experiment_assignments_intervention_lookup_idx
         )

    drop index(:experiment_assignments, [:experiment_id, :intervention_id, :enrollment_id],
           name: :experiment_assignments_intervention_sticky_idx
         )

    drop constraint(:experiment_assignments, :experiment_assignments_scope_identity_check)
    drop constraint(:experiment_assignments, :experiment_assignments_assignment_scope_check)
    drop constraint(:experiment_assignments, :experiment_assignments_experiment_scope_fkey)

    alter table(:experiment_assignments) do
      modify :intervention_id, references(:experiment_interventions, on_delete: :delete_all),
        null: false,
        from: references(:experiment_interventions, on_delete: :delete_all)

      remove :assignment_scope
    end

    create unique_index(:experiment_assignments, [:intervention_id, :enrollment_id],
             name: :experiment_assignments_intervention_sticky_idx
           )

    drop constraint(
           :experiment_definitions,
           :experiment_definitions_algorithm_assignment_scope_check
         )

    drop constraint(:experiment_definitions, :experiment_definitions_assignment_scope_check)

    drop index(:experiment_definitions, [:id, :assignment_scope],
           name: :experiment_definitions_id_assignment_scope_idx
         )

    alter table(:experiment_definitions) do
      remove :assignment_scope
    end
  end
end
