defmodule Oli.Repo.Migrations.SectionStatus do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :status, :string, default: "active"
    end
  end
end
