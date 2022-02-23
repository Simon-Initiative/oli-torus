defmodule Oli.Repo.Migrations.UpdateUsersTablesAgeVerified do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:users) do
      add :age_verified, :boolean, default: false, null: false
    end
  end
end
