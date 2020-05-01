defmodule Oli.Repo.Migrations.CreateDefaultActivityOptions do
  use Ecto.Migration

  def change do
    create table(:default_activity_options) do
      add :resource_slug, :string
      add :max_attempts, :integer
      add :recommended_attempts, :integer
      add :scoring_model, :map
      add :time_limit, :integer
      add :publication_id, references(:publications)

      timestamps(type: :timestamptz)
    end

    create index(:default_activity_options, [:publication_id])

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

    create table(:section_activity_options) do
      add :section_slug, :string
      add :resource_slug, :string
      add :high_stakes, :boolean, default: false, null: false
      add :date_available, :utc_datetime
      add :date_due, :utc_datetime
      add :just_in_time, :boolean, default: false, null: false
      add :score_visibility, :map
      add :attempts_permitted, :integer
      add :attempts_possible, :integer
      add :password, :string
      add :grace_period, :integer
      add :late_mode, :map
      add :enable_review, :boolean, default: false, null: false
      add :enable_hints, :boolean, default: false, null: false
      add :feedback_mode, :map
      add :scoring_model, :map

      timestamps(type: :timestamptz)
    end

  end
end
