defmodule Oli.Repo.Migrations.UpdateAgendaDefaultToTrue do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      modify(:agenda, :boolean, default: true)
    end
  end
end
