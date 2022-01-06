defmodule Oli.Repo.Migrations.GradeUpdate do
  use Ecto.Migration

  def change do
    create table(:lms_grade_updates) do
      add :score, :float, null: false
      add :out_of, :float, null: false
      add :attempt, :integer, null: false
      add :type, :string, null: false, default: "inline"
      add :result, :string, null: false, default: "success"
      add :details, :string
      add :attempt_number, :integer, null: false

      add :resource_access_id, references(:resource_accesses)

      timestamps()
    end

    alter table(:resource_accesses) do
      add :last_successful_grade_update_id, references(:lms_grade_updates)
      add :last_grade_update_id, references(:lms_grade_updates)
    end
  end
end
