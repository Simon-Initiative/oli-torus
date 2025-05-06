defmodule Oli.Repo.Migrations.SoftDeleteAuthorsUsers do
  use Ecto.Migration

  def up do
    alter table(:authors) do
      add :deleted_at, :utc_datetime
    end
  end

  def down do
    alter table(:authors) do
      remove :deleted_at
    end
  end
end
