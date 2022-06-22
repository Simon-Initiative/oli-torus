defmodule Oli.Repo.Migrations.AddPetiteLabel do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :petite_label, :string, null: false, default: ""
    end
  end
end
