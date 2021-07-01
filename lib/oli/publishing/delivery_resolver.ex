defmodule Oli.Publishing.DeliveryResolver do
  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Resolver
  alias Oli.Delivery.Sections.Section
  import Oli.Timing
  import Ecto.Query, warn: false
  alias Oli.Repo

  @behaviour Resolver

  @impl Resolver
  # TODO: update query
  def from_resource_id(section_slug, resource_ids) when is_list(resource_ids) do
    fn ->
      revisions =
        from(s in Section,
          join: m in PublishedResource,
          on: m.publication_id == s.publication_id,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          where: s.slug == ^section_slug and m.resource_id in ^resource_ids,
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
  # TODO: update query
  def from_resource_id(section_slug, resource_id) do
    fn ->
      from(s in Section,
        join: m in PublishedResource,
        on: m.publication_id == s.publication_id,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where: s.slug == ^section_slug and m.resource_id == ^resource_id,
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
        join: r in Resource,
        on: r.id == rev.resource_id,
        join: m in PublishedResource,
        on: m.resource_id == r.id,
        join: rev2 in Revision,
        on: m.revision_id == rev2.id,
        where:
          m.publication_id in subquery(published_publication(section_slug)) and
            rev.slug == ^revision_slug,
        limit: 1,
        select: rev2
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  # TODO: update query
  def publication(section_slug) do
    fn ->
      Repo.one(
        from p in Publication,
          join: s in Section,
          on: p.id == s.publication_id,
          where: s.slug == ^section_slug,
          select: p
      )
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  # TODO: update query
  def root_container(section_slug) do
    fn ->
      from(s in Section,
        join: p in Publication,
        on: p.id == s.publication_id,
        join: m in PublishedResource,
        on: m.publication_id == p.id,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.resource_id == p.root_resource_id and s.slug == ^section_slug and
            s.status != :deleted,
        select: rev
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  # TODO: update query
  def all_revisions_in_hierarchy(section_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    fn ->
      from(s in Section,
        join: p in Publication,
        on: p.id == s.publication_id,
        join: m in PublishedResource,
        on: m.publication_id == p.id,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id) and
            s.slug == ^section_slug,
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
    ids = Enum.join(resource_ids, ",")

    fn ->
      sql = """
      select rev.*
      from published_resources as m
      join sections as c on m.publication_id = c.publication_id
      join revisions as rev on rev.id = m.revision_id
      where c.slug = '#{section_slug}'
        and rev.deleted is false
        and rev.children && ARRAY[#{ids}]
      """

      {:ok, result} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

      Enum.map(result.rows, &Repo.load(Revision, {result.columns, &1}))
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  # TODO: update query
  defp published_publication(section_slug) do
    from(s in Section,
      where: s.slug == ^section_slug,
      select: s.publication_id
    )
  end
end
