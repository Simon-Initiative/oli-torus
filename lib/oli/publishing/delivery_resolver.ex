defmodule Oli.Publishing.DeliveryResolver do
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Resolver
  alias Oli.Delivery.Sections.Section
  import Oli.Timing
  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionsProjectsPublications

  @behaviour Resolver

  defp section_resources(section_slug) do
    from(sr in SectionResource,
      as: :sr,
      join: s in Section,
      as: :s,
      on: s.id == sr.section_id,
      where: s.slug == ^section_slug
    )
  end

  defp section_resource_revisions(section_slug) do
    from([sr, s] in section_resources(section_slug),
      join: spp in SectionsProjectsPublications,
      as: :spp,
      on: s.id == spp.section_id,
      where: sr.project_id == spp.project_id,
      join: pr in PublishedResource,
      as: :pr,
      on: pr.publication_id == spp.publication_id,
      where: pr.resource_id == sr.resource_id,
      join: rev in Revision,
      as: :rev,
      on: rev.id == pr.revision_id
    )
  end

  @impl Resolver
  def from_resource_id(section_slug, resource_ids) when is_list(resource_ids) do
    fn ->
      revisions =
        from([pr: pr, rev: rev] in section_resource_revisions(section_slug),
          where: pr.resource_id in ^resource_ids,
          select: rev
        )
        |> Repo.all()

      # order them according to the resource_ids
      map = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.resource_id, e) end)
      Enum.map(resource_ids, fn resource_id -> Map.get(map, resource_id) end)
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def from_resource_id(section_slug, resource_id) do
    fn ->
      from([s: s, pr: pr, rev: rev] in section_resource_revisions(section_slug),
        where: s.slug == ^section_slug and pr.resource_id == ^resource_id,
        select: rev
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def from_revision_slug(section_slug, revision_slug) do
    fn ->
      from(rev in Revision,
        join: sr in SectionResource,
        as: :sr,
        on: sr.resource_id == rev.resource_id,
        join: s in Section,
        as: :s,
        on: s.id == sr.section_id,
        where: s.slug == ^section_slug,
        join: spp in SectionsProjectsPublications,
        as: :spp,
        on: s.id == spp.section_id,
        where: sr.project_id == spp.project_id,
        join: pr in PublishedResource,
        as: :pr,
        on: pr.publication_id == spp.publication_id,
        where: pr.resource_id == sr.resource_id,
        join: rev2 in Revision,
        as: :rev2,
        on: rev2.id == pr.revision_id,
        where: rev.slug == ^revision_slug,
        limit: 1,
        select: rev2
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def root_container(section_slug) do
    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where: sr.id == s.root_section_resource_id,
        select: rev
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def all_revisions(section_slug) do
    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def all_revisions_in_hierarchy(section_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where: rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id,
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def find_parent_objectives(_, []), do: []

  def find_parent_objectives(section_slug, resource_ids) do
    fn ->
      from(pr in PublishedResource,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        ## postgres && syntax means 'any element in left array is found in right array'
        where:
          pr.publication_id in subquery(section_publication_ids(section_slug)) and
            rev.deleted == false and
            fragment("? && ?", rev.children, ^resource_ids),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  defp section_publication_ids(section_slug) do
    from(s in Section,
      where: s.slug == ^section_slug,
      join: spp in SectionsProjectsPublications,
      on: s.id == spp.section_id,
      select: spp.publication_id
    )
  end
end
