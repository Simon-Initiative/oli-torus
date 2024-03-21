defmodule Oli.Repo.Migrations.ActivityVariables do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :variables, {:array, :string}, default: [], null: false
    end
  end
end
