defmodule Oli.Repo.Migrations.EnsureUniqueActiveSection do
  use Ecto.Migration

  def change do
    # guarantee there is only ever one active section with a given context id
    create unique_index(:sections, [:context_id], where: "status = 'active'", name: :sections_active_context_id_unique_index)
  end
end
