defmodule Oli.Repo.Migrations.DatashopSessionId do
  use Ecto.Migration

  def change do
    alter table(:part_attempts) do
      add :datashop_session_id, :string
    end
  end
end
