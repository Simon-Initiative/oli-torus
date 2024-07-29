defmodule Oli.Repo.Migrations.AssessmentMode do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :assessment_mode, :string, default: "traditional", null: false
    end

    alter table(:delivery_settings) do
      add :assessment_mode, :string, null: true
    end

    alter table(:section_resources) do
      add :assessment_mode, :string, default: "traditional", null: false
    end
  end
end
