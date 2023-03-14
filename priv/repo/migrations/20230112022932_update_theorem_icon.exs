defmodule Oli.Repo.Migrations.UpdateTheoremIcon do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Repo

  def change do
    from(b in "blueprints",
      where: b.name == "Theorem",
      update: [set: [icon: "fa-solid fa-scroll"]]
    )
    |> Repo.update_all([])
  end
end
