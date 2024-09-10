defmodule Oli.Repo.Migrations.DropHostIdentifierTable do
  use Ecto.Migration

  def change do
    drop table(:host_identifier)
  end
end
