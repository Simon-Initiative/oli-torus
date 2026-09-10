defmodule Oli.Repo.Migrations.RemoveLegacyExperimentGates do
  use Ecto.Migration

  def up do
    alter table(:projects) do
      remove :has_experiments
    end

    alter table(:sections) do
      remove :has_experiments
    end
  end

  def down do
    alter table(:projects) do
      add :has_experiments, :boolean, default: false
    end

    alter table(:sections) do
      add :has_experiments, :boolean, default: false
    end
  end
end
