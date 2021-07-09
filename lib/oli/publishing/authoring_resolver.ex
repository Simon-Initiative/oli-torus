defmodule Oli.Publishing.AuthoringResolver do
  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.Resolver
  import Oli.Timing
  import Ecto.Query, warn: false
  alias Oli.Repo

  @behaviour Resolver

  @impl Resolver
  def from_resource_id(project_slug, resource_ids) when is_list(resource_ids) do
    fn ->
      revisions =
        from(m in PublishedResource,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          where:
            m.publication_id in subquery(working_project_publication(project_slug)) and
              m.resource_id in ^resource_ids,
          select: rev
        )
        |> Repo.all()

      # order them according to the resource_ids
      map = Enum.reduce(revisions, %{}, fn e, m -> Map.put(m, e.resource_id, e) end)
      Enum.map(resource_ids, fn resource_id -> Map.get(map, resource_id) end)
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def from_resource_id(project_slug, resource_id) do
    fn ->
      Repo.one(
        from m in PublishedResource,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          where:
            m.publication_id in subquery(working_project_publication(project_slug)) and
              m.resource_id == ^resource_id,
          select: rev
      )
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def from_revision_slug(project_slug, revision_slug) do
    fn ->
      from(rev in Revision,
        join: r in Resource,
        on: r.id == rev.resource_id,
        join: m in PublishedResource,
        on: m.resource_id == r.id,
        join: rev2 in Revision,
        on: m.revision_id == rev2.id,
        where:
          m.publication_id in subquery(working_project_publication(project_slug)) and
            rev.slug == ^revision_slug,
        limit: 1,
        select: rev2
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def root_container(project_slug) do
    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        join: p in Publication,
        on: p.id == m.publication_id,
        join: c in Project,
        on: p.project_id == c.id,
        where:
          p.published == false and m.resource_id == p.root_resource_id and
            c.slug == ^project_slug,
        select: rev
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  @doc """

  """
  def all_revisions(project_slug) do
    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where: m.publication_id in subquery(working_project_publication(project_slug)),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  @doc """

  """
  def all_revisions_in_hierarchy(project_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")
    container_id = Oli.Resources.ResourceType.get_id_by_type("container")

    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.publication_id in subquery(working_project_publication(project_slug)) and
            (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def find_parent_objectives(_, []), do: []

  def find_parent_objectives(project_slug, resource_ids) do
    ids = Enum.join(resource_ids, ",")

    fn ->
      sql = """
      select rev.*
      from published_resources as m
      join publications as p on p.id = m.publication_id
      join projects as c on p.project_id = c.id
      join revisions as rev on rev.id = m.revision_id
      where c.slug = '#{project_slug}'
        and rev.deleted is false
        and p.published = false
        and rev.children && ARRAY[#{ids}]
      """

      {:ok, result} = Ecto.Adapters.SQL.query(Oli.Repo, sql, [])

      Enum.map(result.rows, &Repo.load(Revision, {result.columns, &1}))
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  defp working_project_publication(project_slug) do
    from(p in Publication,
      join: c in Project,
      on: p.project_id == c.id,
      where: p.published == false and c.slug == ^project_slug,
      select: p.id
    )
  end
end
