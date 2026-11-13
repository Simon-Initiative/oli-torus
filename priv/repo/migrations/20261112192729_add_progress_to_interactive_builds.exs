defmodule Oli.Repo.Migrations.AddProgressToInteractiveBuilds do
  use Ecto.Migration

  def up do
    alter table(:interactive_builds) do
      add :transcript, :text, null: false, default: ""
    end

    drop index(:interactive_builds, [:project_id, :resource_id],
           name: :interactive_builds_one_active
         )

    create unique_index(:interactive_builds, [:project_id, :resource_id],
             name: :interactive_builds_one_active,
             where: "status IN ('queued', 'launching', 'running', 'cancelling')"
           )
  end

  def down do
    execute "UPDATE interactive_builds SET status = 'failed' WHERE status IN ('cancelling', 'cancelled')"

    drop index(:interactive_builds, [:project_id, :resource_id],
           name: :interactive_builds_one_active
         )

    create unique_index(:interactive_builds, [:project_id, :resource_id],
             name: :interactive_builds_one_active,
             where: "status IN ('queued', 'launching', 'running')"
           )

    alter table(:interactive_builds) do
      remove :transcript
    end
  end
end
