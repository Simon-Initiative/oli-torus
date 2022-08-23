defmodule Oli.Repo.Migrations.AddDefaultToPublishers do
  use Ecto.Migration

  def up do
    alter table(:publishers) do
      add :default, :boolean, default: false, null: false
    end

    create unique_index(:publishers, [:default],
             where: '"default"',
             name: :publisher_default_true_index
           )

    flush()

    execute """
      UPDATE public.publishers
      SET "default" = true
      WHERE name = 'Torus Publisher';
    """
  end

  def down do
    alter table(:publishers) do
      remove :default
    end
  end
end
