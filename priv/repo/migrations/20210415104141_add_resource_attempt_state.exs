defmodule Oli.Repo.Migrations.AddResourceAttemptState do
  use Ecto.Migration

  def change do
    alter table(:resource_attempts) do
      add :state, :map
    end
  end
end
