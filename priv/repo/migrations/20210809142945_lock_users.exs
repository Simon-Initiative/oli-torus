defmodule Oli.Repo.Migrations.LockUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :locked_at, :utc_datetime
    end

    alter table(:authors) do
      add :locked_at, :utc_datetime
    end
  end
end
