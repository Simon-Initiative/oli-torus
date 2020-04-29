defmodule Oli.Repo.Migrations.CreateUserActivityOption do
  use Ecto.Migration

  def change do
    create table(:user_activity_option) do
      add :section_slug, :string
      add :resource_slug, :string
      add :user_id, :string
      add :high_stakes, :boolean, default: false, null: false
      add :date_available, :utc_datetime
      add :date_due, :utc_datetime
      add :just_in_time, :boolean, default: false, null: false
      add :scoring_model, :map
      add :password, :string
      add :late_start, :boolean, default: false, null: false
      add :time_limit, :integer
      add :grace_period, :integer
      add :late_mode, :map

      timestamps(type: :timestamptz)
    end

  end
end
