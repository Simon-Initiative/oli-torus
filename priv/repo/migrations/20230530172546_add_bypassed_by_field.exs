defmodule Oli.Repo.Migrations.AddBypassedByField do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :bypassed_by_user_id, :integer, null: true
    end
  end
end
