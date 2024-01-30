defmodule Oli.Repo.Migrations.AddCleanupState do
  use Ecto.Migration

  def change do
    alter table(:activity_attempts) do
      add(:cleanup, :integer, default: 0)
    end

    create(index(:activity_attempts, [:cleanup]))
  end
end
