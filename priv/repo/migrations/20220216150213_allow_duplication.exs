defmodule Oli.Repo.Migrations.AllowDuplication do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :allow_duplication, :boolean, default: false, null: false
    end

    flush()

    execute "UPDATE projects SET allow_duplication = false;"

    flush()
  end
end
