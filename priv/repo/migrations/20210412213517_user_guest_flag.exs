defmodule Oli.Repo.Migrations.UserGuestFlag do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def up do
    alter table(:users) do
      add :guest, :boolean, default: false, null: false
    end

    flush()

    from(u in "users")
    |> Oli.Repo.update_all(set: [guest: false])
  end

  def down do
    alter table(:users) do
      remove :guest, :boolean
    end
  end
end
