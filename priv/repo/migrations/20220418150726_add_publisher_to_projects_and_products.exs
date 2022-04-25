defmodule Oli.Repo.Migrations.AddPublisherToProjectsAndProducts do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Inventories
  alias Oli.Inventories.Publisher
  alias Oli.Repo

  require Logger

  def up do
    default_publisher_attrs = %{
      name: Inventories.default_publisher_name(),
      email: "publisher@cmu.edu"
    }

    _publisher =
      Publisher
      |> struct(default_publisher_attrs)
      |> Repo.insert!(on_conflict: :nothing)

    %Publisher{id: publisher_id} = Repo.get_by!(Publisher, default_publisher_attrs)

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
