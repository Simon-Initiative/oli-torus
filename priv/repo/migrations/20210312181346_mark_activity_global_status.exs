defmodule Oli.Repo.Migrations.MarkActivityGlobalStatus do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :globally_available, :boolean, default: false, null: false
    end
  end
end
