defmodule Oli.Repo.Migrations.AddScoreable do
  use Ecto.Migration

  def change do
    alter table(:activity_attempts) do
      add :scoreable, :boolean, default: true
    end

    flush()

    execute "UPDATE activity_attempts SET scoreable = true;"

    flush()
  end
end
