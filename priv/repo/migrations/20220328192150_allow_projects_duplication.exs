defmodule Oli.Repo.Migrations.AllowProjectsDuplication do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :allow_duplication, :boolean, default: false, null: false
    end
  end
end
