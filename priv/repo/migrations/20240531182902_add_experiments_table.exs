defmodule Oli.Repo.Migrations.AddExperimentsTable do
  use Ecto.Migration

  def change do
    create table(:experiments) do
      add :is_enabled, :boolean, default: false, null: false
      add :revision_id, references(:revisions, on_delete: :delete_all), null: false
    end
  end
end
