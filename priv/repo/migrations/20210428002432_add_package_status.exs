defmodule Oli.Repo.Migrations.AddPackageStatus do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :status, :string
    end
  end
end
