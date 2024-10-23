defmodule Oli.Repo.Migrations.DropUsersSubIndex do
  use Ecto.Migration

  def up do
    drop unique_index(:users, [:sub])
  end

  def down do
    create unique_index(:users, [:sub])
  end
end
