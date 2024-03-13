defmodule Oli.Repo.Migrations.CreateVrUserAgentsTable do
  use Ecto.Migration

  def change do
    create table(:vr_user_agents, primary_key: false) do
      add :user_id, references(:users, primary_key: true, on_delete: :delete_all), null: false
      add :value, :boolean, default: false, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:vr_user_agents, :user_id)
  end
end
