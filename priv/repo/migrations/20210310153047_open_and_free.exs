defmodule Oli.Repo.Migrations.OpenAndFree do
  use Ecto.Migration

  def change do
    alter table(:publications) do
      remove :open_and_free, :boolean, default: false, null: false
    end
  end
end
