defmodule Oli.Repo.Migrations.RemoveTimezoneFromSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      remove :timezone, :string, default: "Etc/Greenwich"
    end
  end
end
