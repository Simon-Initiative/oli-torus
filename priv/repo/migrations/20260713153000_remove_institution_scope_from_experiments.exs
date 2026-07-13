defmodule Oli.Repo.Migrations.RemoveInstitutionScopeFromExperiments do
  use Ecto.Migration

  def change do
    drop_if_exists index(:experiment_definitions, [:institution_id])
    drop_if_exists index(:experiment_definitions, [:institution_id, :project_id, :state])

    drop_if_exists index(:experiment_definitions, [:institution_id, :project_id, :state],
                     name: :experiment_definitions_active_scope_idx
                   )

    create_if_not_exists index(:experiment_definitions, [:project_id, :state],
                           name: :experiment_definitions_active_scope_idx
                         )

    alter table(:experiment_definitions) do
      remove_if_exists :institution_id, references(:institutions, on_delete: :nothing)
    end

    alter table(:experiment_assignments) do
      remove_if_exists :institution_id, references(:institutions, on_delete: :nothing)
    end
  end
end
