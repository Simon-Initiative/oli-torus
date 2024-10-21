defmodule Oli.Repo.Migrations.AddInvalidatedByUserId do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :invalidated_by_user_id, :integer, null: true
    end
  end
end
