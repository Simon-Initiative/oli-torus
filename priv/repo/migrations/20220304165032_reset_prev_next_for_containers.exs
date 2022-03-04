defmodule Oli.Repo.Migrations.ResetPrevNextForContainers do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    flush()

    from(s in "sections")
    |> Oli.Repo.update_all(set: [previous_next_index: nil])
  end
end
