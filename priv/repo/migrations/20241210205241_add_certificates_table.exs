defmodule Oli.Repo.Migrations.AddCertificatesTable do
  use Ecto.Migration

  def change do
    create table(:certificates, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :status, :string, default: "pending", null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :section_id, references(:sections, on_delete: :delete_all), null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:certificates, [:user_id, :section_id], name: :unique_user_section)
  end
end
