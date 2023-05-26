defmodule MyApp.Repo.Migrations.AddDisplayModeToRevision do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :display_mode, :integer
    end
  end
end
