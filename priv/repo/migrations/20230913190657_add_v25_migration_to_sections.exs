defmodule Oli.Repo.Migrations.AddV25MigrationToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:v25_migration, :string, default: "not_started", null: false)
    end

    create(index(:sections, :v25_migration))
  end
end
