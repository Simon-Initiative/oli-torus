defmodule Oli.Repo.Migrations.GenerateSectionSlugs do
  use Ecto.Migration

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section

  def change do

    # populate all section slugs that are null
    sections = Oli.Repo.all(
      from s in "sections",
        where: is_nil(s.slug),
        select: s
    )

    Enum.each(sections, fn section ->
      section
      |> Section.changeset(%{})
      |> Slug.update_never("sections")
      |> Oli.Repo.update()
    end)

  end
end
