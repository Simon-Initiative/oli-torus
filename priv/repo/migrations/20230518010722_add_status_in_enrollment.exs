defmodule Oli.Repo.Migrations.AddStatusInEnrollment do
  use Ecto.Migration

  def change do
    alter table(:enrollments) do
      add :status, :string, default: "enrolled"
    end
  end
end
