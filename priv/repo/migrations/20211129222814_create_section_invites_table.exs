defmodule Oli.Repo.Migrations.CreateSectionInvitesTable do
  use Ecto.Migration

  def change do
    create table(:section_invites) do
      add :section_id, references(:sections, on_delete: :delete_all)
      add :slug, :string
      add :date_expires, :utc_datetime

      timestamps(type: :timestamptz)
    end

    create index(:section_invites, [:date_expires])
    create unique_index(:section_invites, [:slug])
  end
end
