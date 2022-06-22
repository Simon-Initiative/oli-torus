defmodule Oli.Repo.Migrations.AddGlobalVisibility do
  use Ecto.Migration

  def change do
    alter table(:activity_registrations) do
      add :globally_visible, :boolean, null: false, default: true
    end

    if direction() == :up do
      flush()

      execute "UPDATE activity_registrations SET globally_visible = true;"
    end
  end
end
