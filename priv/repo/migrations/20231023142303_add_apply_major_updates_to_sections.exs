defmodule Oli.Repo.Migrations.AddApplyMajorUpdatesToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:apply_major_updates, :boolean, default: false)
    end
  end
end
