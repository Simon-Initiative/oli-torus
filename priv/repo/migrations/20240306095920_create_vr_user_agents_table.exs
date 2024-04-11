defmodule Oli.Repo.Migrations.CreateVrUserAgentsTable do
  use Ecto.Migration

  def change do
    create table(:vr_user_agents) do
      add :user_agent, :string, null: false
    end

    create unique_index(:vr_user_agents, :user_agent)
  end
end
