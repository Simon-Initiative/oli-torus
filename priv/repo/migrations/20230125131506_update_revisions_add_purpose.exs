defmodule Oli.Repo.Migrations.UpdateRevisionsAddPurpose do
  use Ecto.Migration

  def up do
    alter table(:revisions) do
      add :purpose, :string, default: "foundation"
      add :relates_to, {:array, :id}, default: []
    end

    execute """
    UPDATE revisions
    SET purpose = 'foundation', relates_to=array[]::integer[];
    """

    alter table(:revisions) do
      modify :purpose, :string, default: "foundation", null: false
      modify :relates_to, {:array, :id}, default: [], null: false
    end
  end


  def down do
    alter table(:revisions) do
      remove :purpose
      remove :tags
    end
  end
end
