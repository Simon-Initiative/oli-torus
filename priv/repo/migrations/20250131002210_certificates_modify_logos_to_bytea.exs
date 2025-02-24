defmodule Oli.Repo.Migrations.CertificatesModifyLogosToBytea do
  use Ecto.Migration

  def up do
    execute("""
    ALTER TABLE certificates
      ALTER COLUMN logo1 TYPE bytea USING logo1::bytea,
      ALTER COLUMN logo2 TYPE bytea USING logo2::bytea,
      ALTER COLUMN logo3 TYPE bytea USING logo3::bytea;
    """)
  end

  def down do
    execute("""
    ALTER TABLE certificates
      ALTER COLUMN logo1 TYPE text USING NULL,
      ALTER COLUMN logo2 TYPE text USING NULL,
      ALTER COLUMN logo3 TYPE text USING NULL;
    """)
  end
end
