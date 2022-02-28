defmodule Oli.Repo.Migrations.LogicBasedGating do
  use Ecto.Migration

  def change do
    alter table(:gating_conditions) do
      add :parent_id, references(:gating_conditions), null: true
    end
  end
end
