defmodule Oli.Repo.Migrations.AddReportToActivityRegistration do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :generates_report, :boolean, default: false
    end
  end
end
