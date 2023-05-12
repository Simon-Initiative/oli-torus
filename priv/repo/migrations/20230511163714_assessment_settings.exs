defmodule Oli.Repo.Migrations.AssessmentSettings do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :late_submit, :string, default: "allow", null: false
      add :late_start, :string, default: "allow", null: false
      add :grace_period, :integer, default: 0, null: false
    end

    alter table(:section_resources) do
      modify :start_date, :utc_datetime
      modify :end_date, :utc_datetime
    end
  end
end
