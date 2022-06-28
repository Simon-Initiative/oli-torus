defmodule Oli.Repo.Migrations.AttemptGroupSurveyIds do
  use Ecto.Migration

  def change do
    alter table(:activity_attempts) do
      add :group_id, :string
      add :survey_id, :string
    end
  end
end
