defmodule Oli.Repo.Migrations.AddSectionResourceMigrationVersion do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:section_resource_migration_version, :integer, null: false, default: 0)
    end

    create(
      constraint(:sections, :sections_section_resource_migration_version_non_negative,
        check: "section_resource_migration_version >= 0"
      )
    )
  end
end
