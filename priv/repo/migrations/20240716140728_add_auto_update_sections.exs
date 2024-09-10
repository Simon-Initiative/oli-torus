defmodule Oli.Repo.Migrations.AddAutoUpdateSections do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :auto_update_sections, :boolean, default: true
    end
  end
end
