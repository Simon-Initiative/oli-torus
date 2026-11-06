defmodule Oli.Repo.Migrations.AddAvailabilityAndProjectGrantsToLtiExternalTools do
  use Ecto.Migration

  def up do
    execute("SET LOCAL lock_timeout = '5s'")

    alter table(:lti_external_tool_activity_deployments) do
      add :availability, :string, null: false, default: "public"
    end

    alter table(:lti_external_tool_activity_deployments) do
      modify :availability, :string, null: false, default: "private"
    end

    create table(:lti_external_tool_project_grants) do
      add :deployment_id,
          references(:lti_external_tool_activity_deployments,
            column: :deployment_id,
            type: :uuid,
            on_delete: :delete_all
          ),
          null: false

      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:lti_external_tool_project_grants, [:deployment_id, :project_id])
    create index(:lti_external_tool_project_grants, [:project_id])
  end

  def down do
    execute("SET LOCAL lock_timeout = '5s'")

    drop table(:lti_external_tool_project_grants)

    alter table(:lti_external_tool_activity_deployments) do
      remove :availability
    end
  end
end
