defmodule Oli.Repo.Migrations.FixPackageStatus do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    flush()

    from(p in "projects",
      where: is_nil(p.status)
    )
    |> Oli.Repo.update_all(set: [status: "active"])
  end
end
