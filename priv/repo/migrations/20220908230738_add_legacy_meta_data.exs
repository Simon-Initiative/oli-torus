defmodule Oli.Repo.Migrations.AddLegacyMetaData do
  use Ecto.Migration

  def change do
    alter table(:revisions) do
      add :legacy, :map
    end

    alter table(:projects) do
      add :legacy_svn_root, :string
    end
  end
end
