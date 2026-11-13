defmodule Oli.Repo.Migrations.AddStateToActivityAttempts do
  use Ecto.Migration

  def up do
    alter table(:activity_attempts) do
      add :state, :map, default: %{}, null: false
    end
  end

  def down do
    alter table(:activity_attempts) do
      remove :state
    end
  end
end
