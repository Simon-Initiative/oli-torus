defmodule Oli.Repo.Migrations.UpdateLtiPlatformInstanceClientIdIndex do
  use Ecto.Migration

  def change do
    drop unique_index(:lti_1p3_platform_instances, :client_id)

    create unique_index(:lti_1p3_platform_instances, :client_id, where: "status = 'active'")
  end
end
