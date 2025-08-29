defmodule Oli.Repo.Migrations.CreateScopedFeatureFlagStates do
  use Ecto.Migration

  def change do
    create table(:scoped_feature_flag_states) do
      add(:feature_name, :string, null: false)
      add(:enabled, :boolean, null: false, default: false)
      add(:project_id, references(:projects, on_delete: :delete_all))
      add(:section_id, references(:sections, on_delete: :delete_all))

      timestamps(type: :utc_datetime)
    end

    # Ensure mutual exclusion: exactly one of project_id or section_id must be set
    create(
      constraint(:scoped_feature_flag_states, :exactly_one_resource,
        check: """
        (project_id IS NOT NULL AND section_id IS NULL) OR 
        (project_id IS NULL AND section_id IS NOT NULL)
        """
      )
    )

    # Unique constraint: one feature flag state per feature per resource
    create(unique_index(:scoped_feature_flag_states, [:feature_name, :project_id]))
    create(unique_index(:scoped_feature_flag_states, [:feature_name, :section_id]))

    # Performance indices for lookups
    create(index(:scoped_feature_flag_states, [:project_id]))
    create(index(:scoped_feature_flag_states, [:section_id]))
    create(index(:scoped_feature_flag_states, [:feature_name]))
  end
end
