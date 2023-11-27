defmodule Oli.Repo.Migrations.AddHasPractice do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:contains_deliberate_practice, :boolean, default: false)
    end
  end
end
