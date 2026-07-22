defmodule Oli.Repo.Migrations.RemovePublicationScopeFromExperiments do
  use Ecto.Migration

  def change do
    drop_if_exists index(:experiment_definitions, [:publication_id])
    drop_if_exists index(:experiment_assignments, [:publication_id])

    alter table(:experiment_definitions) do
      remove_if_exists :publication_id, references(:publications, on_delete: :nothing)
    end

    alter table(:experiment_assignments) do
      remove_if_exists :publication_id, references(:publications, on_delete: :nothing)
    end
  end
end
