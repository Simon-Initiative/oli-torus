defmodule Oli.Repo.Migrations.LtiExternalTools do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:lti_external_tool_deployments, primary_key: false) do
      # The primary key 'id' is the same as the LTI 1.3 deployment ID
      # Postgres will generate a UUID automatically if the value is not provided
      add :id, :uuid, primary_key: true, null: false, default: fragment("gen_random_uuid()")

      add :platform_instance_id,
          references(:lti_1p3_platform_instances, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    # alter table(:lti_1p3_platform_instances) do
    #   add :deployment_id, :string, null: false, default: fragment("gen_random_uuid()")
    # end
  end
end
