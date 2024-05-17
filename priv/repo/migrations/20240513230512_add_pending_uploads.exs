defmodule Oli.Repo.Migrations.AddPendingUploads do
  use Ecto.Migration

  def change do
    create table(:pending_uploads) do
      add :reason, :string, null: false
      add :bundle, :map, null: false
      timestamps()
    end
  end
end
