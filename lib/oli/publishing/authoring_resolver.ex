defmodule Oli.Publishing.AuthoringResolver do
  import Oli.Timing
  import Ecto.Query, warn: false
  import Oli.Utils

  alias Oli.Repo
  alias Oli.Publishing.Resolver
  alias Oli.Resources.Resource
  alias Oli.Resources.Revision
  alias Oli.Publishing.Publications.Publication
  alias Oli.Publishing.PublishedResource
  alias Oli.Authoring.Course.Project
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Authoring.Course
  alias Oli.Branding.CustomLabels

  @behaviour Resolver

  @page_id Oli.Resources.ResourceType.id_for_page()
  @container_id Oli.Resources.ResourceType.id_for_container()

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
    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.publication_id in subquery(project_working_publication(project_slug)) and
            rev.resource_type_id == @page_id and rev.deleted == false,
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
            rev.resource_type_id == ^resource_type_id and rev.deleted == false,
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  @impl Resolver
  def all_revisions_in_hierarchy(project_slug) do
    fn ->
      from(m in PublishedResource,
        join: rev in Revision,
        on: rev.id == m.revision_id,
        where:
          m.publication_id in subquery(project_working_publication(project_slug)) and
            (rev.resource_type_id == @page_id or rev.resource_type_id == @container_id),
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  def project_working_publication(project_slug) do
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
        project,
        revisions_by_resource_id,
        numbering_tracker,
        level
      )

    root_node
  end

  def hierarchy_node_with_children(
        revision,
        project,
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
              project,
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

    labels =
      case project.customizations do
        nil -> CustomLabels.default_map()
        l -> Map.from_struct(l)
      end

    {
      %HierarchyNode{
        uuid: uuid(),
        numbering: %Numbering{
          index: numbering_index,
          level: level,
          labels: labels
        },
        children: children,
        resource_id: revision.resource_id,
        project_id: project.id,
        revision: revision,
        section_resource: nil
      },
      numbering_tracker
    }
  end

  @doc """
  Returns the current revisions of all page resources whose purpose type matches the one it receives as parameter
  ## Examples
      iex> get_by_purpose(valid_project_slug, valid_purpose)
      [%Revision{}, ...]

      iex> get_by_purpose(invalid_project_slug, invalid_purpose)
      []
  """

  def get_by_purpose(project_slug, purpose) do
    Repo.all(
      from(
        revision in Revision,
        join: pub_res in PublishedResource,
        on: pub_res.revision_id == revision.id,
        where:
          pub_res.publication_id in subquery(project_working_publication(project_slug)) and
            revision.purpose ==
              ^purpose and
            revision.resource_type_id == @page_id and revision.deleted == false,
        order_by: [asc: :resource_id]
      )
    )
  end

  @doc """
  Returns the current revisions of all page resources whose have the given resource_id in their "relates_to" attribute
  ## Examples
      iex> targeted_via_related_to(valid_project_slug, valid_resource_id)
      [%Revision{}, ...]

      iex> targeted_via_related_to(invalid_project_slug, invalid_resource_id)
      []
  """

  def targeted_via_related_to(project_slug, resource_id) do
    Repo.all(
      from(
        revision in Revision,
        join: pub_res in PublishedResource,
        on: pub_res.revision_id == revision.id,
        where:
          pub_res.publication_id in subquery(project_working_publication(project_slug)) and
            ^resource_id in revision.relates_to and
            revision.resource_type_id == @page_id and
            revision.deleted == false,
        order_by: [asc: :resource_id]
      )
    )
  end

  @doc """
  Returns all unique youtube video intro urls in the project
  """

  def all_unique_youtube_intro_videos(project_slug) do
    Repo.all(
      from(
        revision in Revision,
        join: pub_res in PublishedResource,
        on: pub_res.revision_id == revision.id,
        where:
          pub_res.publication_id in subquery(project_working_publication(project_slug)) and
            revision.deleted == false and not is_nil(revision.intro_video) and
            (ilike(revision.intro_video, "%youtube.com%") or
               ilike(revision.intro_video, "%youtu.be%")),
        distinct: revision.intro_video,
        select: revision.intro_video
      )
    )
  end

  @fragment """
            SELECT jsonb_agg(
              jsonb_build_object(
                'idref', (elem->>'idref')::INT,
                'href', split_part(elem->>'href', '/', 4)
              )
            )
            FROM LATERAL jsonb_path_query(
              ?, 'strict $.** \\? ((@.type == "a" && @.linkType == "page") || @.type == "page_link")'
            ) AS elem
            """
            |> String.replace(~r/\s+/, " ")

  @doc """
  Returns a list of pages that contains links pointing to the given page
  """
  @spec find_hyperlink_references(project_slug :: String.t(), page_slug :: String.t()) :: [
          %{title: String.t(), slug: String.t()}
        ]
  def find_hyperlink_references(project_slug, page_slug) do
    project_slug
    |> find_raw_references()
    |> process_and_filter_references(project_slug, page_slug)
  end

  defp find_raw_references(project_slug) do
    PublishedResource
    |> join(:inner, [pr], r in Revision, on: r.id == pr.revision_id, as: :rev)
    |> where([pr, _r], pr.publication_id in subquery(project_working_publication(project_slug)))
    |> where([_pr, r], r.resource_type_id == @page_id)
    |> where([_pr, r], r.deleted == false)
    |> where([_pr, r], not is_nil(fragment(@fragment, r.content)))
    |> select([_pr, r], %{slug: r.slug, refs: fragment(@fragment, r.content), title: r.title})
    |> Repo.all()
  end

  # Function that processes the given references to return only the ones pointing to the specified page slug.
  defp process_and_filter_references(raw_references_data, project_slug, page_slug) do
    # Collect the resource_ids and transform the refs from a map to a list
    # For instance, %{refs: [%{"href" => nil, "idref" => 1}, %{"href" => "some_slug", "idref" => nil}]}
    # will be transformed to [1, "some_slug"]
    {resource_ids, data_with_refs_as_list} =
      Enum.reduce(raw_references_data, {[], []}, fn
        %{refs: refs} = data, acc ->
          {hrefs, idrefs} =
            Enum.reduce(refs, {[], []}, fn
              %{"href" => nil, "idref" => idref}, acc2 -> {elem(acc2, 0), [idref | elem(acc2, 1)]}
              %{"href" => href, "idref" => nil}, acc2 -> {[href | elem(acc2, 0)], elem(acc2, 1)}
            end)

          resource_ids = idrefs ++ elem(acc, 0)
          references_list = [%{data | refs: hrefs ++ idrefs} | elem(acc, 1)]
          {resource_ids, references_list}
      end)

    res_id_to_rev_slug_map = map_resource_id_to_rev_slug(project_slug, resource_ids)

    # Map resource_ids and filter references by the given page_slug
    Enum.reduce(data_with_refs_as_list, [], fn data, acc ->
      refs_maped =
        Enum.reduce(data.refs, [], fn
          reference, acc2 when is_number(reference) -> [res_id_to_rev_slug_map[reference] | acc2]
          reference, acc2 -> [reference | acc2]
        end)

      if page_slug in refs_maped,
        do: [%{title: data.title, slug: data.slug} | acc],
        else: acc
    end)
  end

  defp map_resource_id_to_rev_slug(project_slug, resource_ids) do
    from(m in PublishedResource,
      join: rev in Revision,
      on: rev.id == m.revision_id,
      where:
        m.publication_id in subquery(project_working_publication(project_slug)) and
          m.resource_id in ^resource_ids,
      select: {rev.resource_id, rev.slug}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end
end
