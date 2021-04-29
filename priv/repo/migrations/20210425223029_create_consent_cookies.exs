defmodule Oli.Repo.Migrations.CreateConsentCookies do
  use Ecto.Migration

  def change do
    create table(:consent_cookies) do
      add :name, :string
      add :value, :string
      add :expiration, :utc_datetime
      add :user_id, references(:users, on_delete: :nothing)

      timestamps(type: :timestamptz)
    end

    create index(:consent_cookies, [:user_id])
    create unique_index(:consent_cookies, [:user_id, :name], name: :index_name_user)
  end
end
