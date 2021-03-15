defmodule Oli.Repo.Migrations.MarkActivityGlobalStatus do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:activity_registrations) do
      add :globally_available, :boolean, default: false, null: false
    end

    flush()

    from(a in "activity_registrations", where: a.slug in [
      "oli_multiple_choice",
      "oli_check_all_that_apply",
      "oli_short_answer",
      "oli_ordering"
    ])
    |> Oli.Repo.update_all(set: [globally_available: true])

  end
end
