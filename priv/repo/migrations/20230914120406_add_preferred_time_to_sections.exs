defmodule Oli.Repo.Migrations.AddPreferredTimeToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:preferred_scheduling_time, :time, default: "23:59:59")
    end
  end
end
