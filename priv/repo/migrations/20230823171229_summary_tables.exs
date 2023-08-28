defmodule Oli.Repo.Migrations.SummaryTables do
  use Ecto.Migration

  def change do

    create table(:project_resource_summary) do

      add :project_id, references(:projects)
      add :publication_id, references(:publications)
      add :revision_id, references(:revisions)

      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)
      add :part_id, :string

      add :num_correct, :integer
      add :num_attempts, :integer
      add :num_hints, :integer
      add :num_first_attempts, :integer
      add :num_first_attempts_correct, :integer

      timestamps(type: :timestamptz)
    end

    create index(:project_resource_summary, [:project_id, :resource_id, :part_id], name: :project_resource_summary_project_resource_id_part_id_index)])
    create index(:project_resource_summary, [:project_id, :publication_id, :revision_id, :part_id], name: :project_resource_summary_project_publication_revision_part_id_index)])

    create table(:section_resource_summary) do

      add :section_id, references(:sections)
      add :user_id, references(:users)
      # add :group_id, references(:groups)

      add :resource_id, references(:resources)
      add :resource_type_id, references(:resource_types)
      add :part_id, :string

      add :num_correct, :integer
      add :num_attempts, :integer
      add :num_hints, :integer
      add :num_first_attempts, :integer
      add :num_first_attempts_correct, :integer

      timestamps(type: :timestamptz)
    end

    create table(:section_response_summary) do

      add :section_id, references(:sections)
      add :page_id, references(:resources)
      add :activity_id, references(:resources)
      add :part_id, :string

      add :label, :string
      add :count, :integer

      timestamps(type: :timestamptz)
    end

    create table(:student_responses) do

      add :section_response_summary_id, references(:section_response_summary)
      add :user_id, references(:users)

      timestamps(type: :timestamptz)
    end

  end
end
