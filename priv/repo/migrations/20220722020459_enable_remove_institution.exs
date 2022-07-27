defmodule Oli.Repo.Migrations.EnableRemoveInstitution do
  use Ecto.Migration

  def change do
    alter table(:institutions) do
      add :status, :string, default: "active"
    end
  end
end
