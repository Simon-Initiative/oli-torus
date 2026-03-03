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
  alias Oli.Activities.ActivityRegistration

  @behaviour Resolver

  @page_id Oli.Resources.ResourceType.id_for_page()
  @container_id Oli.Resources.ResourceType.id_for_container()
  @activity_id Oli.Resources.ResourceType.id_for_activity()

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

  @doc """
  Retrieves revisions by title for a given project, optionally filtered by resource type.
  The title matching is case-insensitive using ILIKE.

  Returns a list of revisions that match the title (can be multiple if there are duplicates).
  """
  def from_title(project_slug, title, resource_type_id \\ nil) do
    fn ->
      query =
        from(m in PublishedResource,
          join: rev in Revision,
          on: rev.id == m.revision_id,
          where:
            m.publication_id in subquery(project_working_publication(project_slug)) and
              ilike(rev.title, ^title) and
              rev.deleted == false,
          select: rev
        )

      query =
        if resource_type_id do
          from([m, rev] in query,
            where: rev.resource_type_id == ^resource_type_id
          )
        else
          query
        end

      Repo.all(query)
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
    (find_raw_references(project_slug) ++ find_raw_adaptive_references(project_slug))
    |> merge_reference_rows_by_page()
    |> process_and_filter_references(project_slug, page_slug)
  end

  defp merge_reference_rows_by_page(rows) when is_list(rows) do
    rows
    |> Enum.reduce(%{}, fn %{slug: slug, title: title, refs: refs}, acc ->
      key = {slug, title}
      merged_refs = Map.get(acc, key, []) ++ List.wrap(refs)
      Map.put(acc, key, %{slug: slug, title: title, refs: merged_refs})
    end)
    |> Map.values()
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

  defp find_raw_adaptive_references(project_slug) do
    adaptive_activity_refs =
      fetch_adaptive_activity_revisions(project_slug)
      |> Enum.map(fn %{resource_id: resource_id, content: content} ->
        {resource_id, adaptive_hyperlink_refs(content)}
      end)
      |> Enum.reject(fn {_resource_id, refs} -> refs == [] end)

    adaptive_activity_resource_ids = Enum.map(adaptive_activity_refs, &elem(&1, 0))

    activity_to_pages =
      pages_grouped_by_related_activity(project_slug, adaptive_activity_resource_ids)

    Enum.flat_map(adaptive_activity_refs, fn {activity_resource_id, refs} ->
      activity_to_pages
      |> Map.get(activity_resource_id, [])
      |> Enum.map(fn %{slug: slug, title: title} ->
        %{slug: slug, title: title, refs: refs}
      end)
    end)
  end

  defp fetch_adaptive_activity_revisions(project_slug) do
    PublishedResource
    |> join(:inner, [pr], r in Revision, on: r.id == pr.revision_id)
    |> join(:inner, [_pr, r], ar in ActivityRegistration, on: ar.id == r.activity_type_id)
    |> where(
      [pr, _r, _ar],
      pr.publication_id in subquery(project_working_publication(project_slug))
    )
    |> where([_pr, r, _ar], r.resource_type_id == @activity_id and r.deleted == false)
    |> where([_pr, _r, ar], ar.slug == "oli_adaptive")
    |> select([_pr, r, _ar], %{resource_id: r.resource_id, content: r.content})
    |> Repo.all()
  end

  defp pages_grouped_by_related_activity(_project_slug, []), do: %{}

  defp pages_grouped_by_related_activity(project_slug, activity_resource_ids) do
    activity_resource_ids_set = MapSet.new(activity_resource_ids)

    from(pr in PublishedResource,
      join: rev in Revision,
      on: rev.id == pr.revision_id,
      where:
        pr.publication_id in subquery(project_working_publication(project_slug)) and
          rev.resource_type_id == @page_id and rev.deleted == false and
          fragment("? && ?", rev.relates_to, ^activity_resource_ids),
      select: %{slug: rev.slug, title: rev.title, relates_to: rev.relates_to}
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn page, acc ->
      Enum.reduce(page.relates_to || [], acc, fn related_resource_id, acc2 ->
        if MapSet.member?(activity_resource_ids_set, related_resource_id) do
          Map.update(
            acc2,
            related_resource_id,
            [%{slug: page.slug, title: page.title}],
            fn pages ->
              [%{slug: page.slug, title: page.title} | pages]
            end
          )
        else
          acc2
        end
      end)
    end)
    |> Map.new(fn {resource_id, pages} ->
      {resource_id, Enum.uniq_by(pages, & &1.slug)}
    end)
  end

  defp adaptive_hyperlink_refs(content) when is_map(content) do
    content
    |> get_in(["authoring", "parts"])
    |> List.wrap()
    |> Enum.flat_map(&adaptive_hyperlink_refs_for_part/1)
  end

  defp adaptive_hyperlink_refs(_), do: []

  defp adaptive_hyperlink_refs_for_part(%{"type" => "janus-text-flow"} = part) do
    part
    |> get_in(["custom", "nodes"])
    |> List.wrap()
    |> Enum.flat_map(&adaptive_hyperlink_refs_for_node/1)
  end

  defp adaptive_hyperlink_refs_for_part(_), do: []

  defp adaptive_hyperlink_refs_for_node(%{"tag" => "a"} = node) do
    idref =
      (Map.get(node, "idref") || Map.get(node, "resource_id"))
      |> to_integer_or_nil()

    href = Map.get(node, "href") |> internal_page_slug_from_href()

    current_refs =
      if is_nil(idref) and is_nil(href) do
        []
      else
        [%{"idref" => idref, "href" => href}]
      end

    current_refs ++ adaptive_hyperlink_refs_for_children(node)
  end

  defp adaptive_hyperlink_refs_for_node(node) when is_map(node) do
    adaptive_hyperlink_refs_for_children(node)
  end

  defp adaptive_hyperlink_refs_for_node(_), do: []

  defp adaptive_hyperlink_refs_for_children(node) do
    node
    |> Map.get("children", [])
    |> List.wrap()
    |> Enum.flat_map(&adaptive_hyperlink_refs_for_node/1)
  end

  defp internal_page_slug_from_href("/course/link/" <> rest) do
    case String.split(rest, ["?", "#"], parts: 2) do
      [slug | _] when slug != "" -> slug
      _ -> nil
    end
  end

  defp internal_page_slug_from_href(_), do: nil

  defp to_integer_or_nil(resource_id) when is_integer(resource_id), do: resource_id

  defp to_integer_or_nil(resource_id) when is_binary(resource_id) do
    case Integer.parse(resource_id) do
      {value, ""} -> value
      _ -> nil
    end
  end

  defp to_integer_or_nil(_), do: nil

  # Function that processes the given references to return only the ones pointing to the specified page slug.
  defp process_and_filter_references(raw_references_data, project_slug, page_slug) do
    # Collect the resource_ids and transform the refs from a map to a list
    # For instance, %{refs: [%{"href" => nil, "idref" => 1}, %{"href" => "some_slug", "idref" => nil}]}
    # will be transformed to [1, "some_slug"]
    {resource_ids, data_with_refs_as_list} =
      Enum.reduce(raw_references_data, {[], []}, fn %{refs: refs} = data, acc ->
        {hrefs, idrefs} =
          Enum.reduce(refs || [], {[], []}, fn ref, {href_acc, idref_acc} ->
            href_acc =
              case Map.get(ref, "href") do
                href when is_binary(href) and href != "" -> [href | href_acc]
                _ -> href_acc
              end

            idref_acc =
              case Map.get(ref, "idref") do
                idref when is_integer(idref) -> [idref | idref_acc]
                _ -> idref_acc
              end

            {href_acc, idref_acc}
          end)

        {idrefs ++ elem(acc, 0), [%{data | refs: hrefs ++ idrefs} | elem(acc, 1)]}
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
