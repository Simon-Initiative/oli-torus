defmodule Oli.Repo.Migrations.LtiExternalTools do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto"

    create table(:lti_external_tool_activity_deployments, primary_key: false) do
      # The primary key 'id' is the same as the LTI 1.3 deployment ID
      # Postgres will generate a UUID automatically if the value is not provided
      add :deployment_id, :uuid,
        primary_key: true,
        null: false,
        default: fragment("gen_random_uuid()")

      add :activity_registration_id,
          references(:activity_registrations, on_delete: :delete_all),
          null: false

      add :platform_instance_id,
          references(:lti_1p3_platform_instances, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    # Add unique index to ensure that only one deployment exists for a platform instance
    create unique_index(:lti_external_tool_activity_deployments, :platform_instance_id)

    # Add unique index to ensure that only one deployment exists for an activity registration
    create unique_index(:lti_external_tool_activity_deployments, :activity_registration_id)

    # In order to support the activity_registratoin-based lti deployment approach, we must relax
    # some of the existing unique constraints on the activity_registrations table
    drop unique_index(:activity_registrations, [:delivery_element],
           name: :index_delivery_element_registrations
         )

    drop unique_index(:activity_registrations, [:authoring_element],
           name: :index_authoring_element_registrations
         )

    drop unique_index(:activity_registrations, [:delivery_script],
           name: :index_delivery_script_registrations
         )

    drop unique_index(:activity_registrations, [:authoring_script],
           name: :index_authoring_script_registrations
         )
  end

  def down do
    drop table(:lti_external_tool_activity_deployments)
  end
end
