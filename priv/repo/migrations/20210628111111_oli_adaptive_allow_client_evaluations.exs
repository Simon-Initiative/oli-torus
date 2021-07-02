defmodule Oli.Repo.Migrations.UpdateAdaptiveActivityClientMigration do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    flush()

    from(p in "activity_registrations",
      where: p.slug == "oli_adaptive"
    )
    |> Oli.Repo.update_all(set: [allow_client_evaluation: true])
  end
end
