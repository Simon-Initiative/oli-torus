defmodule Oli.Repo.Migrations.PublishVersionDescription do
  use Ecto.Migration

  def change do
    alter table(:publications) do
      remove :published, :boolean
    end

    flush()

    alter table(:publications) do
      add :published, :utc_datetime_usec
      add :description, :text
      add :major, :integer, default: 0
      add :minor, :integer, default: 0
      add :patch, :integer, default: 0
    end

    # TODO: Migrate published:boolean to utc_datetime using updated_at

  end
end
