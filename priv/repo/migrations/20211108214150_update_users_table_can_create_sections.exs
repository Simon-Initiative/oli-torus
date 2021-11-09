defmodule Oli.Repo.Migrations.UpdateUsersTableCanCreateSections do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:users) do
      add :can_create_sections, :boolean, default: false, null: false
    end

    flush()

    from(u in "users",
      where: is_nil(u.can_create_sections)
    )
    |> Oli.Repo.update_all(set: [can_create_sections: false])
  end
end
