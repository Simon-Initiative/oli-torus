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


    create table(:resource_part_responses) do

      add :resource_id, references(:resources)
      add :part_id, :string
      add :response, :string
      add :label, :string

    end

    create unique_index(:resource_part_responses, [:resource_id, :part_id, :response], name: :resourse_part_response_unique)

    create table(:response_summary) do

      add :project_id, :integer
      add :publication_id, :integer
      add :section_id, :integer
      add :page_id, references(:resources)
      add :activity_id, references(:resources)
      add :part_id, :string
      add :resource_part_response_id, references(:resource_part_responses)

      add :count, :integer

    end

    create unique_index(:response_summary, [:project_id, :publication_id, :section_id, :page_id, :activity_id, :part_id, :resource_part_response_id], name: :response_summary_scopes)

    create table(:student_responses) do

      add :section_id, references(:sections)
      add :page_id, references(:resources)
      add :resource_part_response_id, references(:resource_part_responses)
      add :user_id, references(:users)

    end

    create unique_index(:student_responses, [:section_id, :page_id, :resource_part_response_id, :user_id], name: :student_responses_unique)

  end
end
