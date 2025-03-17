defmodule Oli.Repo.Migrations.AddScoreAsYouGo do
  use Ecto.Migration

  def up do

    alter table(:revisions) do
      add :batch_scoring, :boolean, default: true
      add :replacement_strategy, :binary, default: "none"
    end

    alter table(:section_resources) do
      add :batch_scoring, :boolean, default: true
      add :replacement_strategy, :binary, default: "none"
    end

    alter table(:delivery_settings) do
      add :batch_scoring, :boolean
      add :replacement_strategy, :binary
    end

    alter table(:activity_attempts) do
      add :aggregate_out_of, :float
      add :aggregate_score, :float
    end

  end

  def down do
    alter table(:revisions) do
      remove :batch_scoring
      remove :replacement_strategy
    end

    alter table(:section_resources) do
      remove :batch_scoring
      remove :replacement_strategy
    end

    alter table(:delivery_settings) do
      remove :batch_scoring
      remove :replacement_strategy
    end

    alter table(:activity_attempts) do
      remove :aggregate_out_of
      remove :aggregate_score
    end

  end
end
