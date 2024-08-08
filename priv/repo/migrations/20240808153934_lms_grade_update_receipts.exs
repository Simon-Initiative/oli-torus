defmodule Oli.Repo.Migrations.LmsGradeUpdateReceipts do
  use Ecto.Migration

  def change do
    alter table(:lms_grade_updates) do
      add :receipt, :text
    end
  end
end
