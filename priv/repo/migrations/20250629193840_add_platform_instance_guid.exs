defmodule Oli.Repo.Migrations.AddPlatformInstanceGuid do
  use Ecto.Migration

  def up do
    alter table(:lti_1p3_platform_instances) do
      add :guid, :string, null: false, default: fragment("gen_random_uuid()")
    end

    create unique_index(:lti_1p3_platform_instances, [:guid])
  end

  def down do
    alter table(:lti_1p3_platform_instances) do
      remove :guid
    end

    drop index(:lti_1p3_platform_instances, [:guid])
  end
end
