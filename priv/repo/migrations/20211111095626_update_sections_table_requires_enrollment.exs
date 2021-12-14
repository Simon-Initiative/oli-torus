defmodule Oli.Repo.Migrations.UpdateSectionsTableRequiresEnrollment do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:sections) do
      add :requires_enrollment, :boolean, default: false, null: false
    end

    flush()

    from(s in "sections",
      where: is_nil(s.requires_enrollment)
    )
    |> Oli.Repo.update_all(set: [requires_enrollment: false])
  end
end
