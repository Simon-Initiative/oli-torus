defmodule Oli.Repo.Migrations.HasExperiments do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :has_experiments, :boolean, default: false
    end
    alter table(:sections) do
      add :has_experiments, :boolean, default: false
    end
  end
end
