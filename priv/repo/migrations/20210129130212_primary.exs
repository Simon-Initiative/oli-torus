defmodule Oli.Repo.Migrations.Primary do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :primary_resource_id, references(:resources)
    end

  end
end
