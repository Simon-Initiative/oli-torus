defmodule Oli.Repo.Migrations.AddSurveyFieldsForSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :class_modality, :string, default: "never"
      add :class_days, {:array, :string}, default: []
      add :course_section_number, :string
    end
  end
end
