defmodule Oli.Repo.Migrations.AddUrlToGrantedCertificates do
  use Ecto.Migration

  def change do
    alter table(:granted_certificates) do
      add :url, :string
    end
  end
end
