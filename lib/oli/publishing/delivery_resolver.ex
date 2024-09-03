defmodule Oli.Publishing.DeliveryResolver do
  import Oli.Timing
  import Ecto.Query, warn: false
  import Oli.Utils

  alias Oli.Analytics.Summary.ResourceSummary
  alias Oli.Repo
  alias Oli.Publishing.Resolver
  alias Oli.Resources.Revision
  alias Oli.Publishing.PublishedResource
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Branding.CustomLabels
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Authoring.Course.Project

  defp section_resources(section_slug) do
    from(sr in SectionResource,
      as: :sr,
      join: s in Section,
      as: :s,
      on: s.id == sr.section_id,
      where: s.slug == ^section_slug
    )
  end

  def section_resource_revisions(section_slug) do
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

  def graded_pages_revisions_and_section_resources(section_slug) do
    from([sr, s, _spp, _pr, rev] in section_resource_revisions(section_slug),
      where: rev.resource_type_id == 1 and rev.graded == true,
      select: {rev, sr},
      order_by: [asc: sr.numbering_level, asc: sr.numbering_index]
    )
    |> Repo.all()
  end

  def ungraded_pages_revisions_and_section_resources(section_slug) do
    from([sr, s, _spp, _pr, rev] in section_resource_revisions(section_slug),
      where: rev.resource_type_id == 1 and rev.graded == false,
      select: {
        map(rev, [:id, :resource_id, :title]),
        map(sr, [:scheduling_type, :end_date])
      },
      order_by: [asc: sr.numbering_index, asc: sr.numbering_level]
    )
    |> Repo.all()
  end

  def students_with_attempts_for_page(
        page,
        %Section{analytics_version: :v2, id: section_id} = _section,
        student_ids
      ) do
    from(rs in ResourceSummary,
      where:
        rs.section_id == ^section_id and rs.resource_id == ^page.resource_id and
          rs.user_id in ^student_ids,
      distinct: rs.user_id,
      select: rs.user_id
    )
    |> Repo.all()
  end

  def students_with_attempts_for_page(
        page,
        %Section{id: section_id},
        student_ids
      ) do
    from(ra in ResourceAttempt,
      join: rac in ResourceAccess,
      on: ra.resource_access_id == rac.id,
      where:
        ra.lifecycle_state == :evaluated and
          rac.section_id == ^section_id and rac.user_id in ^student_ids and
          rac.resource_id == ^page.resource_id,
      group_by: rac.user_id,
      select: rac.user_id
    )
    |> Repo.all()
  end

  def objectives_by_resource_ids(nil, _section_slug), do: []

  def objectives_by_resource_ids(resource_ids, section_slug) do
    from([_sr, _s, _spp, _pr, rev] in section_resource_revisions(section_slug),
      where: rev.resource_id in ^resource_ids,
      select: rev
    )
    |> Repo.all()
  end

  @behaviour Resolver

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
        limit: 1,
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
  def all_pages(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where: rev.resource_type_id == ^page_id,
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @doc """
  Returns the first page slug for a given section
  """
  @spec get_first_page_slug(String.t()) :: String.t()
  def get_first_page_slug(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id,
      select: rev.slug,
      order_by: [asc: sr.numbering_index],
      limit: 1
    )
    |> Repo.one()
  end

  def practice_pages_revisions_and_section_resources_with_surveys(section_slug) do
    from([sr, s, _spp, _pr, rev] in section_resource_revisions(section_slug),
      join: content_elem in fragment("jsonb_array_elements(?->'model')", rev.content),
      on: true,
      where:
        rev.resource_type_id == 1 and rev.deleted == false and
          fragment("?->>'type'", content_elem) == "survey",
      select: {
        map(rev, [:id, :resource_id, :title]),
        map(sr, [:scheduling_type, :end_date])
      },
      order_by: [asc: sr.numbering_level, asc: sr.numbering_index]
    )
    |> Repo.all()
  end

  def pages_with_attached_objectives(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where:
          rev.resource_type_id == ^page_id and
            fragment("? != '[]'", rev.objectives["attached"]),
        select: %{
          resource_id: rev.resource_id,
          objectives: rev.objectives
        }
      )
      |> Repo.all()
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

  @doc """
  Returns the revisions of a given list of section ids that are of the given resource type
  and belong to the given project
  """
  @spec project_revisions_by_section_ids([integer()], String.t(), integer()) :: [Revision.t()]
  def project_revisions_by_section_ids(section_ids, project_slug, resource_type_id) do
    from(sr in SectionResource,
      join: s in Section,
      on: s.id == sr.section_id,
      where: s.id in ^section_ids,
      join: spp in SectionsProjectsPublications,
      on: s.id == spp.section_id,
      where: sr.project_id == spp.project_id,
      join: p in Project,
      on: p.id == spp.project_id,
      where: p.slug == ^project_slug,
      join: pr in PublishedResource,
      on: pr.publication_id == spp.publication_id,
      where: pr.resource_id == sr.resource_id,
      join: rev in Revision,
      on: rev.id == pr.revision_id,
      where: rev.resource_type_id == ^resource_type_id and rev.deleted == false,
      select: rev
    )
  end

  @impl Resolver
  def revisions_of_type(section_slug, resource_type_id) do
    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where: rev.resource_type_id == ^resource_type_id and rev.deleted == false,
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def all_revisions_in_hierarchy(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()
    container_id = Oli.Resources.ResourceType.id_for_container()

    fn ->
      from([s: s, sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where:
          rev.resource_type_id == ^page_id or
            rev.resource_type_id == ^container_id,
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :delivery], :duration)
  end

  @impl Resolver
  def full_hierarchy(section_slug) do
    {hierarchy_nodes, root_hierarchy_node} = hierarchy_nodes_by_sr_id(section_slug)

    hierarchy_node_with_children(root_hierarchy_node, hierarchy_nodes)
  end

  defp hierarchy_node_with_children(
         %HierarchyNode{children: children_ids} = node,
         nodes_by_sr_id
       ) do
    Map.put(
      node,
      :children,
      Enum.map(children_ids, fn sr_id ->
        Map.get(nodes_by_sr_id, sr_id)
        |> hierarchy_node_with_children(nodes_by_sr_id)
      end)
    )
  end

  # Returns a map of resource ids to hierarchy nodes and the root hierarchy node
  defp hierarchy_nodes_by_sr_id(section_slug) do
    page_id = Oli.Resources.ResourceType.id_for_page()
    container_id = Oli.Resources.ResourceType.id_for_container()

    fn ->
      from(
        [s: s, sr: sr, rev: rev, spp: spp] in section_resource_revisions(section_slug),
        join: p in Project,
        on: p.id == spp.project_id,
        where:
          rev.resource_type_id == ^page_id or
            rev.resource_type_id == ^container_id,
        select:
          {s, sr, rev,
           fragment(
             "CASE WHEN ? = ? THEN true ELSE false END",
             sr.id,
             s.root_section_resource_id
           ), p.slug}
      )
      |> Repo.all()
      |> Enum.reduce({%{}, nil}, fn {s, sr, rev, is_root?, proj_slug}, {nodes, root} ->
        labels =
          case s.customizations do
            nil -> CustomLabels.default_map()
            l -> Map.from_struct(l)
          end

        node = %HierarchyNode{
          uuid: uuid(),
          numbering: %Numbering{
            index: sr.numbering_index,
            level: sr.numbering_level,
            labels: labels
          },
          children: sr.children,
          resource_id: rev.resource_id,
          project_id: sr.project_id,
          project_slug: proj_slug,
          revision: rev,
          section_resource: sr
        }

        {
          Map.put(
            nodes,
            sr.id,
            node
          ),
          if(is_root?, do: node, else: root)
        }
      end)
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
        order_by: [rev.inserted_at, rev.id],
        select: rev
      )
      |> Repo.all()
    end
    |> run()
    |> emit([:oli, :resolvers, :authoring], :duration)
  end

  def section_publication_ids(section_slug) do
    from(s in Section,
      where: s.slug == ^section_slug,
      join: spp in SectionsProjectsPublications,
      on: s.id == spp.section_id,
      select: spp.publication_id
    )
  end

  @doc """
  Returns the current revisions of all page resources whose purpose type matches the one it receives as parameter
  ## Examples
      iex> get_by_purpose(valid_section_slug, valid_purpose)
      [%Revision{}, ...]

      iex> get_by_purpose(invalid_section_slug, invalid_purpose)
      []
  """
  def get_by_purpose(section_slug, purpose) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    Repo.all(
      from([sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where:
          rev.purpose == ^purpose and rev.deleted == false and
            rev.resource_type_id == ^page_id,
        select: rev,
        order_by: [asc: sr.numbering_index]
      )
    )
  end

  @doc """
  Returns the current revisions of all page resources whose have the given resource_id in their "relates_to" attribute
  ## Examples
      iex> targeted_via_related_to(valid_section_slug, valid_resource_id)
      [%Revision{}, ...]

      iex> targeted_via_related_to(invalid_section_slug, invalid_resource_id)
      []
  """
  def targeted_via_related_to(section_slug, resource_id) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    Repo.all(
      from([sr: sr, rev: rev] in section_resource_revisions(section_slug),
        where:
          ^resource_id in rev.relates_to and rev.deleted == false and
            rev.resource_type_id == ^page_id,
        select: rev,
        order_by: [asc: :resource_id]
      )
    )
  end

  def get_sections_for_products(product_ids) do
    from(section in Section,
      where: section.blueprint_id in ^product_ids,
      select: section.id
    )
    |> Repo.all()
  end
end
