defmodule Oli.Repo.Migrations.DropPublicationScope do
  use Ecto.Migration

  def up do

    execute("""
    DELETE FROM resource_summary WHERE publication_id != -1
    """)

    execute("""
    DELETE FROM response_summary WHERE publication_id != -1
    """)

    execute("""
    DROP INDEX IF EXISTS resource_summary_scopes;
    """)

    execute("""
    DROP INDEX IF EXISTS response_summary_scopes;
    """)

    alter table(:resource_summary) do
      remove :publication_id
    end

    create unique_index(
             :resource_summary,
             [
               :project_id,
               :section_id,
               :user_id,
               :resource_id,
               :resource_type_id,
               :part_id
             ],
             name: :resource_summary_scopes
           )

    alter table(:response_summary) do
      remove :publication_id
    end

    create unique_index(
             :response_summary,
             [
               :project_id,
               :section_id,
               :page_id,
               :activity_id,
               :part_id,
               :resource_part_response_id
             ],
             name: :response_summary_scopes
           )
  end

  def down do
    alter table(:resource_summary) do
      add :publication_id, :integer, default: -1
    end
    alter table(:response_summary) do
      add :publication_id, :integer, default: -1
    end
  end
end
