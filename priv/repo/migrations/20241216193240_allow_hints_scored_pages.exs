defmodule Oli.Repo.Migrations.AllowHintsScoredPages do
  use Ecto.Migration

  def change do
    alter table(:section_resources) do
      add :allow_hints, :boolean, default: false
    end
  end
end
