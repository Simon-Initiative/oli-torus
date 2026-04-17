defmodule Oli.Repo.Migrations.AddUnnumberedUnitIdsToSections do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :unnumbered_unit_ids, {:array, :integer}, default: [], null: false
    end
  end
end
