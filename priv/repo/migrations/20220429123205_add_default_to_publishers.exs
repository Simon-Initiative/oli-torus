defmodule Oli.Repo.Migrations.AddDefaultToPublishers do
  use Ecto.Migration

  alias Oli.Inventories.Publisher
  alias Oli.Repo

  def up do
    alter table(:publishers) do
      add :default, :boolean, default: false, null: false
    end

    create unique_index(:publishers, [:default],
             where: '"default"',
             name: :publisher_default_true_index
           )

    flush()

    default_publisher_attrs = %{name: "Torus Publisher"}
    default_publisher = Repo.get_by!(Publisher, default_publisher_attrs)

    default_publisher
    |> Publisher.changeset(%{default: true})
    |> Repo.update()
  end

  def down do
    alter table(:publishers) do
      remove :default
    end
  end
end
