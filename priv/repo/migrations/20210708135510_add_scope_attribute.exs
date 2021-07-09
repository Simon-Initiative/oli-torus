defmodule Oli.Repo.Migrations.AddScopeAttribute do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    alter table(:revisions) do
      add :scope, :string, default: false, null: false
    end

    flush()

    from(p in "revisions",
      where: is_nil(p.scope)
    )
    |> Oli.Repo.update_all(set: [scope: "embedded"])
  end
end
