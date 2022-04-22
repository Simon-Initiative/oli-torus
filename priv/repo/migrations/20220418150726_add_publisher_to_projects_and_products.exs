defmodule Oli.Repo.Migrations.AddPublisherToProjectsAndProducts do
  use Ecto.Migration

  import Ecto.Query, warn: false

  alias Oli.Delivery.Sections.Section
  alias Oli.Inventories
  alias Oli.Inventories.Publisher
  alias Oli.Repo

  require Logger

  def up do
    default_publisher_attrs = %{name: Inventories.default_publisher_name(), email: "publisher@cmu.edu"}

    case Inventories.find_or_create_publisher(default_publisher_attrs) do
      {:ok, %Publisher{id: publisher_id}} ->
        alter table(:sections) do
          add :publisher_id, references(:publishers)
        end

        alter table(:projects) do
          add :publisher_id, references(:publishers), null: false, default: publisher_id
        end

        flush()

        #Set default publisher for products
        from(s in Section, where: s.type == :blueprint)
        |> Repo.update_all(set: [publisher_id: publisher_id])

      {:error, error} ->
        Logger.error("Could not set default publisher for projects and products due to an error: #{error}")
    end
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
