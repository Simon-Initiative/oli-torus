defmodule Oli.Repo.Migrations.AddRemovedFromScheduleFieldToSectionResouces do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :removed_from_schedule, :boolean, default: false
    end
  end
end
