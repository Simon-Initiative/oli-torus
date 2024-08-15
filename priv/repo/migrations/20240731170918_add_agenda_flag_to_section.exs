defmodule Oli.Repo.Migrations.AddAgendaFlagToSection do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add(:agenda, :boolean, default: false)
    end
  end
end
