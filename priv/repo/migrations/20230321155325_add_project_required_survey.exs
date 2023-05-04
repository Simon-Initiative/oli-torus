defmodule Oli.Repo.Migrations.AddProjectRequiredSurvey do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :required_survey_resource_id, references(:resources)
    end

    alter table(:sections) do
      add :required_survey_resource_id, references(:resources)
    end
  end
end
