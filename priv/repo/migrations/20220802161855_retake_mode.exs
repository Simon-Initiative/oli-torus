defmodule Oli.Repo.Migrations.RetakeMode do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :retake_mode, :string, default: "normal", null: false
    end

    alter table(:activity_attempts) do
      add :selection_id, :string
    end
  end
end
