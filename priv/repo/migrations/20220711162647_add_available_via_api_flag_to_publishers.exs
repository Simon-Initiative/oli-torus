defmodule Oli.Repo.Migrations.AddAvailableViaApiFlagToPublishers do
  use Ecto.Migration

  def change do
    alter table(:publishers) do
      add :available_via_api, :boolean, null: false, default: true
    end
  end
end
