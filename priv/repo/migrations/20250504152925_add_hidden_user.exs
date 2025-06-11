defmodule Oli.Repo.Migrations.AddHiddenUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :hidden, :boolean, default: false
    end
  end
end
