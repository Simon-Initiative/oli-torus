defmodule Oli.Repo.Migrations.EnableLtiExternalToolDeepLinking do
  use Ecto.Migration

  def up do
    alter table(:lti_external_tool_activity_deployments) do
      add :deep_linking_enabled, :boolean, default: false
    end

    create table(:lti_section_resource_deep_links) do
      add :type, :string
      add :url, :string
      add :title, :string
      add :text, :string
      add :custom, :map, default: %{}
      add :resource_id, references(:resources, on_delete: :delete_all)
      add :section_id, references(:sections, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    # For now, the system will only allow one deep link per section and resource.
    create unique_index(:lti_section_resource_deep_links, [:resource_id, :section_id],
             name: :unique_section_resource_deep_link
           )
  end

  def down do
    drop table(:lti_section_resource_deep_links)

    alter table(:lti_external_tool_activity_deployments) do
      remove :deep_linking_enabled
    end
  end
end
