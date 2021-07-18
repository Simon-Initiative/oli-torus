defmodule Oli.Publishing.AuthoringResolver do
  import Oli.Timing
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Publishing.Resolver
  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Authoring.Course.Project
  alias Oli.Publishing.HierarchyNode
  alias Oli.Resources.Numbering

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

  defp working_project_publication(project_slug) do
    from(p in Publication,
      join: c in Project,
      on: p.project_id == c.id,
      where: p.published == false and c.slug == ^project_slug,
      select: p.id
    )
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

  @impl Resolver
  def full_hierarchy(project_slug) do
    revisions_by_resource_id =
      all_revisions_in_hierarchy(project_slug)
      |> Enum.reduce(%{}, fn r, m -> Map.put(m, r.resource_id, r) end)

    root_revision = root_container(project_slug)
    numberings = Numbering.init_numberings()
    level = 0

    {root_node, _numberings} =
      hierarchy_node_with_children(root_revision, revisions_by_resource_id, numberings, level)

    root_node
  end

  def hierarchy_node_with_children(revision, revisions_by_resource_id, numberings, level) do
    {numbering_index, numberings} = Numbering.next_index(numberings, level, revision)

    {children, numberings} =
      Enum.reduce(
        revision.children,
        {[], numberings},
        fn resource_id, {nodes, numberings} ->
          {node, numberings} =
            hierarchy_node_with_children(
              revisions_by_resource_id[resource_id],
              revisions_by_resource_id,
              numberings,
              level + 1
            )

          {[node | nodes], numberings}
        end
      )
      # it's more efficient to append to list using [node | nodes] and
      # then reverse than to concat on every reduce call using ++
      |> then(fn {children, numberings} ->
        {Enum.reverse(children), numberings}
      end)

    {
      %HierarchyNode{
        numbering: %Numbering{
          index: numbering_index,
          level: level,
          revision: revision
        },
        children: children,
        resource_id: revision.resource_id,
        revision: revision,
        section_resource: nil
      },
      numberings
    }
  end
end
