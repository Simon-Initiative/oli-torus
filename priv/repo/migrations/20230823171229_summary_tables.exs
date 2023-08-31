defmodule Oli.Repo.Migrations.SummaryTables do
  use Ecto.Migration

  def change do

    create table(:resource_summary) do

      add :project_id, :integer
      add :publication_id, :integer
      add :section_id, :integer
      add :user_id, :integer
      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)
      add :part_id, :string

      add :num_correct, :integer
      add :num_attempts, :integer
      add :num_hints, :integer
      add :num_first_attempts, :integer
      add :num_first_attempts_correct, :integer

    end

    # add a unique index to resource_summary for the scope of the summary
    # this is to prevent duplicate records from being inserted
    create unique_index(:resource_summary, [:project_id, :publication_id, :section_id, :user_id, :resource_id, :resource_type_id, :part_id], name: :resource_summary_scopes)

    create table(:response_summary) do

      add :project_id, :integer
      add :publication_id, :integer
      add :section_id, :integer
      add :page_id, references(:resources)
      add :activity_id, references(:resources)
      add :part_id, :string

      add :label, :string
      add :count, :integer

      timestamps(type: :timestamptz)
    end

    create table(:student_responses) do

      add :response_summary_id, references(:response_summary)
      add :user_id, references(:users)

      timestamps(type: :timestamptz)
    end

  end
end
