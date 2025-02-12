defmodule Oli.Repo.Migrations.AlterGrantedCertificatedIssuedByTypeType do
  use Ecto.Migration

  def up do
    execute(
      "ALTER TYPE public.granted_certificates_issued_by_type RENAME VALUE 'autor' TO 'author';"
    )
  end

  def down do
    execute("DROP TYPE IF EXISTS public.granted_certificates_issued_by_type CASCADE;")
  end
end
