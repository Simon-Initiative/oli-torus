defmodule Oli.Repo.Migrations.EnableLtiExternalToolDeepLinking do
  use Ecto.Migration

  def change do
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
  end
end
