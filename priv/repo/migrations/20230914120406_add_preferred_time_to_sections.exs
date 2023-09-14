defmodule Oli.Repo.Migrations.AddPreferredTimeToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:preferred_scheduling_time, :time, null: true)
    end
  end
end
