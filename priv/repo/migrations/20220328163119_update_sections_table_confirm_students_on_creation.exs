defmodule Oli.Repo.Migrations.UpdateSectionsTableConfirmStudentsOnCreation do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :confirm_students_on_creation, :boolean, default: false, null: false
    end
  end
end
