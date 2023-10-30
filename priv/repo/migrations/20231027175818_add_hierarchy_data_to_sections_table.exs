defmodule Oli.Repo.Migrations.AddHierarchyDataToSectionsTable do
  use Ecto.Migration
  import Ecto.Query, warn: false

  def up do
    alter table(:sections) do
      add :full_hierarchy, :map
    end

    flush()

    # Fetch all sections
    sections =
      Oli.Repo.all(
        from(s in "sections",
          select: %{id: s.id, slug: s.slug}
        )
      )

    # Iterate over each section and update the full_hierarchy
    Enum.each(sections, fn section ->
      hierarchy =
        Oli.Publishing.DeliveryResolver.full_hierarchy(section.slug)

      Oli.Repo.update_all(
        from(s in "sections", where: s.id == ^section.id),
        set: [full_hierarchy: hierarchy]
      )
    end)
  end

  def down do
    alter table(:sections) do
      remove :full_hierarchy
    end
  end
end
