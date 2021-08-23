defmodule Oli.Repo.Migrations.PublishVersionDescription do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Repo

  def up do
    alter table(:publications) do
      add :published_tmp, :utc_datetime_usec
    end

    flush()

    # Migrate published:boolean to utc_datetime using the updated_at value
    from(p in "publications",
      where: p.published == true,
      update: [set: [published_tmp: p.updated_at]]
    )
    |> Repo.update_all([])

    flush()

    alter table(:publications) do
      remove :published, :boolean
      add :description, :text
      add :major, :integer, default: 0
      add :minor, :integer, default: 0
      add :patch, :integer, default: 0
    end

    flush()

    rename table(:publications), :published_tmp, to: :published
  end

  def down do
    alter table(:publications) do
      add :published_tmp, :boolean
    end

    flush()

    from(p in "publications",
      where: not is_nil(p.published),
      update: [set: [published_tmp: true]]
    )
    |> Repo.update_all([])

    flush()

    alter table(:publications) do
      remove :published, :boolean
      remove :description, :text
      remove :major, :integer, default: 0
      remove :minor, :integer, default: 0
      remove :patch, :integer, default: 0
    end

    rename table(:publications), :published_tmp, to: :published
  end
end
