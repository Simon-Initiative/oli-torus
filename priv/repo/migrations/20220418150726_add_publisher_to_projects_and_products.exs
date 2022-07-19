defmodule Oli.Repo.Migrations.AddPublisherToProjectsAndProducts do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Inventories.Publisher
  alias Oli.Repo

  require Logger

  def up do
    execute """
      INSERT INTO publishers(email, name, inserted_at, updated_at)
      VALUES ('publisher@cmu.edu', 'Torus Publisher', now(), now())
      ON CONFLICT DO NOTHING
    """

    flush()

    publisher_id =
      Repo.one(from(p in Publisher, where: p.name == "Torus Publisher", select: p.id))

    flush()

    alter table(:sections) do
      add :publisher_id, references(:publishers)
    end

    alter table(:projects) do
      add :publisher_id, references(:publishers), null: false, default: publisher_id
    end

    flush()

    # Set default publisher for products
    from(s in Section, where: s.type == :blueprint)
    |> Repo.update_all(set: [publisher_id: publisher_id])
  end

  def down do
    alter table(:sections) do
      remove :publisher_id, references(:publishers)
    end

    alter table(:projects) do
      remove :publisher_id, references(:publishers)
    end
  end
end
