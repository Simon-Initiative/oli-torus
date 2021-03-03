defmodule Oli.Repo.Migrations.EliminateUserInstFkey do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :institution_id, references(:institutions)
    end
  end
end
