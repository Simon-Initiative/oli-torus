defmodule Oli.Repo.Migrations.AddLicenseColumnsToProjects do
  use Ecto.Migration

  def up do
    execute """
    DO $$ BEGIN
      CREATE TYPE license_type AS ENUM
      ('none', 'custom', 'cc_by', 'cc_by_sa', 'cc_by_nc', 'cc_by_nc_sa', 'cc_by_nd', 'cc_by_nc_nd');
      EXCEPTION
        WHEN duplicate_object THEN null;
    END $$;
    """

    flush()

    alter table(:projects) do
      add_if_not_exists(:license, :license_type, default: "none")
      add_if_not_exists(:custom_license_details, :string, default: "")
    end
  end

  def down do
    alter table(:projects) do
      remove_if_exists(:license, :license_type)
      remove_if_exists(:custom_license_details, :string)
    end

    execute("DROP TYPE IF EXISTS license_type")
  end
end
