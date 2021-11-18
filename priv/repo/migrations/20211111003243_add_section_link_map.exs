defmodule Oli.Repo.Migrations.AddSectionLinkMap do
  use Ecto.Migration

  def change do
    alter table(:sections) do
      add :previous_next_index, :map, default: nil, null: true
    end
  end
end
