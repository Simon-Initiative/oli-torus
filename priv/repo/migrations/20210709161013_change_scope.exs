defmodule Oli.Repo.Migrations.ChangeScope do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    alter table(:revisions) do
      modify :scope, :string, default: "embedded", null: false
    end

    flush()

    from("revisions")
    |> Oli.Repo.update_all(set: [scope: "embedded"])
  end
end
