defmodule Oli.Repo.Migrations.UpdateSectionsTablePayByInstitution do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :pay_by_institution, :boolean, default: false, null: false
    end
  end
end
