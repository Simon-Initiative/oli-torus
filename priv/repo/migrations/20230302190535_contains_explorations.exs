defmodule Oli.Repo.Migrations.ContainsExplorations do
  use Ecto.Migration

  def up do
    alter table(:sections) do
      add :contains_explorations, :boolean, default: false
    end

    flush()

    execute "UPDATE sections SET contains_explorations = true WHERE id in (SELECT sec.id FROM sections as sec
    JOIN section_resources as sr on sr.section_id = sec.id
    JOIN revisions as rev on rev.resource_id = sr.resource_id
    WHERE rev.purpose = 'application' and rev.deleted = false and rev.resource_type_id = 1 group by sec.id)"
  end

  def down do
    alter table(:sections) do
      remove :contains_explorations, :boolean, default: false
    end
  end
end
