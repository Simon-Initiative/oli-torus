defmodule Oli.Repo.Migrations.AddCertificatesTable do
  use Ecto.Migration

  def change do
    create table(:certificates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :section_id, references(:sections, on_delete: :delete_all), null: false
      add :certificate_url, :string, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:certificates, [:user_id, :section_id], name: :unique_user_section)
    create unique_index(:certificates, [:certificate_url], name: :unique_certificate_url)
  end
end
