defmodule Oli.Repo.Migrations.AddTimezoneToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :timezone, :string, default: "Etc/UTC"
    end
  end
end
