defmodule Oli.Repo.Migrations.PublishVersionDescription do
  use Ecto.Migration

  def change do
    alter table(:publications) do
      add :description, :text
      add :major, :integer, default: 0
      add :minor, :integer, default: 0
      add :patch, :integer, default: 0
    end
  end
end
