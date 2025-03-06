defmodule Oli.Repo.Migrations.AddFullProgressPct do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :full_progress_pct, :integer, default: 100
    end
  end
end
