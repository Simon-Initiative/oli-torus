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
  end
end
