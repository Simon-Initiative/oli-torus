defmodule Oli.Repo.Migrations.AddIssuerIndex do
  use Ecto.Migration

  def change do
    create index(:granted_certificates, [:issued_by_type, :issued_by])
  end
end
