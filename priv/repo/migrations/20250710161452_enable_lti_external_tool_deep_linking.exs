defmodule Oli.Repo.Migrations.EnableLtiExternalToolDeepLinking do
  use Ecto.Migration

  def change do
    alter table(:lti_external_tool_activity_deployments) do
      add :deep_linking_enabled, :boolean, default: false
    end
  end
end
