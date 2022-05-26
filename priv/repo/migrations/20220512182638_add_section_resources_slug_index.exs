defmodule Oli.Repo.Migrations.AddSectionResourcesSlugIndex do
  use Ecto.Migration

  def change do
    create index(:section_resources, [:slug])
  end
end
