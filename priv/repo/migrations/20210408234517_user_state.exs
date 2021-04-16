defmodule Oli.Repo.Migrations.UserState do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :state, :map
    end

    alter table(:enrollments) do
      add :state, :map
    end
  end
end
