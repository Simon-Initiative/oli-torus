defmodule Oli.Repo.Migrations.CreateSystemMessages do
  use Ecto.Migration

  def change do
    create table(:system_messages) do
      add :message, :text, null: false
      add :active, :boolean, default: false, null: false
      add :start, :utc_datetime
      add :end, :utc_datetime

      timestamps(type: :timestamptz)
    end
  end
end
