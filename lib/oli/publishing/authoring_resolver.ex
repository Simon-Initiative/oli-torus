defmodule Oli.Publishing.AuthoringResolver do
  import Oli.Timing
  import Ecto.Query, warn: false
  import Oli.Utils

  alias Oli.Repo
  alias Oli.Publishing.Resolver
  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Authoring.Course

  @behaviour Resolver

  @impl Resolver
  def from_resource_id(project_slug, resource_ids) when is_list(resource_ids) do
    fn ->
      revisions =
        from(m in PublishedResource,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          where:
            m.publication_id in subquery(project_working_publication(project_slug)) and
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
            m.publication_id in subquery(project_working_publication(project_slug)) and
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
          m.publication_id in subquery(project_working_publication(project_slug)) and
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
          is_nil(p.published) and m.resource_id == p.root_resource_id and
            c.slug == ^project_slug,
        select: rev
      )
      |> Repo.one()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def all_pages(project_slug) do
    page_id = Oli.Resources.ResourceType.get_id_by_type("page")

    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.publication_id in subquery(project_working_publication(project_slug)) and
            rev.resource_type_id == ^page_id and rev.deleted == false,
        select: rev
      )
      |> Repo.all()
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
        where: m.publication_id in subquery(project_working_publication(project_slug)),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def revisions_of_type(project_slug, resource_type_id) do
    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.publication_id in subquery(project_working_publication(project_slug)) and
            rev.resource_type_id == ^resource_type_id,
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
          m.publication_id in subquery(project_working_publication(project_slug)) and
            (rev.resource_type_id == ^page_id or rev.resource_type_id == ^container_id),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  defp project_working_publication(project_slug) do
    from(p in Publication,
      join: c in Project,
      on: p.project_id == c.id,
      where: is_nil(p.published) and c.slug == ^project_slug,
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
        and p.published is NULL
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

    project = Course.get_project_by_slug(project_slug)
    root_revision = root_container(project_slug)
    numbering_tracker = Numbering.init_numbering_tracker()
    level = 0

    {root_node, _numbering_tracker} =
      hierarchy_node_with_children(
        root_revision,
        project.id,
        revisions_by_resource_id,
        numbering_tracker,
        level
      )

    root_node
  end

  def hierarchy_node_with_children(
        revision,
        project_id,
        revisions_by_resource_id,
        numbering_tracker,
        level
      ) do
    {numbering_index, numbering_tracker} =
      Numbering.next_index(numbering_tracker, level, revision)

    {children, numbering_tracker} =
      Enum.reduce(
        revision.children,
        {[], numbering_tracker},
        fn resource_id, {nodes, numbering_tracker} ->
          {node, numbering_tracker} =
            hierarchy_node_with_children(
              revisions_by_resource_id[resource_id],
              project_id,
              revisions_by_resource_id,
              numbering_tracker,
              level + 1
            )

          {[node | nodes], numbering_tracker}
        end
      )
      # it's more efficient to append to list using [node | nodes] and
      # then reverse than to concat on every reduce call using ++
      |> then(fn {children, numbering_tracker} ->
        {Enum.reverse(children), numbering_tracker}
      end)

    {
      %HierarchyNode{
        uuid: uuid(),
        numbering: %Numbering{
          index: numbering_index,
          level: level
        },
        children: children,
        resource_id: revision.resource_id,
        project_id: project_id,
        revision: revision,
        section_resource: nil
      },
      numbering_tracker
    }
  end
end
