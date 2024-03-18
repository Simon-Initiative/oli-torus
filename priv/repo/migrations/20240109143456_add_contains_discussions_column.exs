defmodule Oli.Repo.Migrations.AddContainsDiscussionsColumn do
  use Ecto.Migration

  def up do
    alter table(:sections) do
      add :contains_discussions, :boolean, default: false
    end

    flush()

    execute("""
    UPDATE sections SET contains_discussions = true WHERE id IN (
      SELECT sr.section_id
      FROM section_resources sr
      WHERE sr.collab_space_config ->>'status' = 'enabled'
      GROUP BY sr.section_id
    )
    """)
  end

  def down do
    alter table(:sections) do
      remove :contains_discussions
    end
  end
end
