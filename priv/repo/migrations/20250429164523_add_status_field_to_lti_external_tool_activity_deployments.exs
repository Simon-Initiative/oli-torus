defmodule Oli.Repo.Migrations.AddStatusFieldToLtiExternalToolActivityDeployments do
  use Ecto.Migration

  def change do
    alter table(:lti_external_tool_activity_deployments) do
      add :status, :string, default: "enabled", null: false
    end
  end
end
