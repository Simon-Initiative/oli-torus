defmodule Oli.Utils.BibUtils do
  @doc """
  Assembles all of the bibliography references from a page and the activities that are
  contained within it.  Returns a list of the unique revisions of the bibliography
  entries, resolved using the supplied resolver.
  """
  def assemble_bib_entries(content, activities, activity_bib_provider_fn, section_slug, resolver) do
    page_bib_ids = Map.get(content, "bibrefs", [])

    activity_bib_ids =
      if activities != nil do
        Enum.map(activities, fn a ->
          activity_bib_provider_fn.(a)
        end)
        |> List.flatten()
      else
        []
      end

    all_unique_bib_ids = Enum.uniq(page_bib_ids ++ activity_bib_ids)

    staff = resolver.from_resource_id(section_slug, all_unique_bib_ids)
    staff
  end

  def serialize_revision(%Oli.Resources.Revision{} = revision, ordinal) do
    %{
      title: revision.title,
      id: revision.resource_id,
      slug: revision.slug,
      content: revision.content,
      ordinal: ordinal
    }
  end
end
