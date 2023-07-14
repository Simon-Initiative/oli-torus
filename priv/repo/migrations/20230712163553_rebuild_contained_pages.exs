defmodule Oli.Repo.Migrations.RebuildContainedPages do
  use Ecto.Migration
  import Ecto.Query, warn: false

  alias Oli.Repo

  def change do
      from(s in "sections",
      select: %{id: s.id, slug: s.slug, root_section_resource_id: s.root_section_resource_id}
    )
    |> Repo.all()
    |> Enum.each(fn s ->
      Oli.Delivery.Sections.rebuild_contained_pages(s)
    end)

  end
end
