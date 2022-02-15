defmodule Oli.Repo.Migrations.UpdateUsersTablesAgeVerified do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def change do
    alter table(:users) do
      add :age_verified, :boolean, default: true, null: false
    end

    flush()

    from(u in "users",
      where: is_nil(u.age_verified)
    )
    |> Oli.Repo.update_all(set: [age_verified: true])
  end
end
