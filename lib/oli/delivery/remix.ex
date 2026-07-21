defmodule Oli.Delivery.Remix do
  @moduledoc """
  Remix domain module that owns non-UI business logic and state transitions.

  - Auth-agnostic: callers must pass authorized inputs (section + actor).
  - Exposes pure functions for state evolution and a single `save/1` to persist.
  - LiveView delegates to this module for Remix behavior.

  References:
  - PRD: docs/features/refactor_remix/prd.md
  - FDD: docs/features/refactor_remix/fdd.md
  """

  import Ecto.Query, warn: false

  alias Oli.Delivery.Remix.ContainerCreation
  alias Oli.Delivery.Remix.Source
  alias Oli.Delivery.Remix.State
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Groups.{Community, CommunityVisibility}
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing.{PublishedResource, Publications.Publication}
  alias Oli.Authoring.Course.Project
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Accounts
  alias Oli.Accounts.{User, Author}
  alias Oli.Repo

  @default_page_limit 5
  @max_page_limit 100
  @max_page_offset 10_000

  @doc """
  Initialize Remix state from a section and an actor (Author or User).

  Returns {:ok, %State{}} on success.
  """
  @spec init(Section.t(), User.t() | Author.t()) :: {:ok, State.t()} | {:error, term()}
  def init(%Section{type: :enrollable} = section, %User{hidden: true} = user) do
    section = Repo.preload(section, :institution)
    user = Repo.preload(user, :author)

    available_sources =
      Publishing.retrieve_visible_sources(user, section.institution)
      |> sources_for(section)
      |> maybe_include_hidden_instructor_product_sources(section, user)

    build_initial_state(section, available_sources)
  end

  def init(%Section{} = section, %User{} = user) do
    section = Repo.preload(section, :institution)
    user = Repo.preload(user, :author)

    available_sources =
      Publishing.retrieve_visible_sources(user, section.institution)
      |> sources_for(section)

    build_initial_state(section, available_sources)
  end

  def init(%Section{} = section, %Author{} = author) do
    section = Repo.preload(section, :institution)

    available_sources =
      Publishing.available_publications(author, section.institution)
      |> Enum.map(&Source.project/1)
      |> pin_precedence(section)

    build_initial_state(section, available_sources)
  end

  @doc """
  Initialize Remix state for an administrator acting as the instructor of an
  enrollable course section.

  This is intentionally scoped to real course sections so product/template
  source visibility is not added to generic author initialization or product
  template editing.
  """
  @spec init_admin_instructor(Section.t(), Author.t()) :: {:ok, State.t()} | {:error, term()}
  def init_admin_instructor(%Section{type: :enrollable} = section, %Author{} = author) do
    case Accounts.at_least_content_admin?(author) do
      true ->
        section = Repo.preload(section, :institution)

        project_sources =
          Publishing.all_available_publications()
          |> Enum.map(&Source.project/1)

        available_sources =
          (project_sources ++ all_product_sources())
          |> pin_precedence(section)

        build_initial_state(section, available_sources)

      false ->
        {:error, :unauthorized}
    end
  end

  def init_admin_instructor(%Section{}, %Author{}), do: {:error, :unsupported_section_type}

  defp sources_for(sources, section) do
    product_pinned_publications =
      sources
      |> Enum.filter(&match?(%Section{}, &1))
      |> Enum.map(& &1.id)
      |> Sections.get_pinned_project_publications_for_sections()

    sources =
      Enum.map(sources, fn
        %Publication{} = publication ->
          Source.project(publication)

        %Section{} = product ->
          Source.product(product, Map.get(product_pinned_publications, product.id, %{}))
      end)

    pin_precedence(sources, section)
  end

  defp maybe_include_hidden_instructor_product_sources(sources, section, user) do
    case Sections.is_instructor?(user, section.slug) do
      true -> include_community_sources(sources, section)
      false -> sources
    end
  end

  defp include_community_sources(sources, section) do
    (sources ++ all_community_project_sources() ++ all_community_product_sources())
    |> Enum.uniq_by(& &1.key)
    |> pin_precedence(section)
  end

  defp all_community_project_sources do
    from(community in Community,
      join: visibility in CommunityVisibility,
      on: visibility.community_id == community.id,
      join: project in Project,
      on: project.id == visibility.project_id and project.status == :active,
      join: last_publication in subquery(Publishing.last_publication_query()),
      on: last_publication.project_id == project.id,
      join: publication in Publication,
      on: publication.id == last_publication.id,
      where: community.status == :active,
      select: %{publication | project: project},
      distinct: true
    )
    |> Repo.all()
    |> Enum.map(&Source.project/1)
  end

  defp all_community_product_sources do
    products =
      from(product in Section,
        join: visibility in CommunityVisibility,
        on: visibility.section_id == product.id,
        join: community in Community,
        on: community.id == visibility.community_id and community.status == :active,
        where: product.type == :blueprint and product.status == :active,
        group_by: [product.id, product.title, product.slug],
        order_by: [asc: product.title],
        select: struct(product, [:id, :title, :slug])
      )
      |> Repo.all()

    products_to_sources(products)
  end

  defp all_product_sources do
    products =
      from(product in Section,
        where: product.type == :blueprint and product.status == :active,
        order_by: [asc: product.title],
        select: struct(product, [:id, :title, :slug])
      )
      |> Repo.all()

    products_to_sources(products)
  end

  defp products_to_sources(products) do
    product_pinned_publications =
      products
      |> Enum.map(& &1.id)
      |> Sections.get_pinned_project_publications_for_sections()

    Enum.map(products, fn product ->
      Source.product(product, Map.get(product_pinned_publications, product.id, %{}))
    end)
  end

  defp pin_precedence(sources, %Section{id: section_id}) do
    pinned = Sections.get_pinned_project_publications(section_id)

    Enum.map(sources, fn
      %Source{type: :project, project_id: project_id} = source ->
        publication =
          Map.get(pinned, project_id, publication_by_id!(source, source.publication_id))

        %{
          source
          | publication_id: publication.id,
            pinned_publications: %{project_id => publication},
            key: "project:#{publication.id}"
        }

      source ->
        source
    end)
  end

  @doc """
  Initialize Remix state for open-and-free context using all available publications.
  """
  @spec init_open_and_free(Section.t()) :: {:ok, State.t()} | {:error, term()}
  def init_open_and_free(%Section{} = section) do
    section = Repo.preload(section, :institution)

    available_sources =
      Publishing.all_available_publications()
      |> Enum.map(&Source.project/1)
      |> pin_precedence(section)

    build_initial_state(section, available_sources)
  end

  defp build_initial_state(section, available_sources) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    {:ok,
     %State{
       section: section,
       hierarchy: hierarchy,
       previous_hierarchy: hierarchy,
       active: hierarchy,
       pinned_project_publications: Sections.get_pinned_project_publications(section.id),
       available_sources: available_sources
     }}
  end

  @doc "Returns the authorized source with the supplied key, if any."
  @spec source_by_key(State.t(), String.t()) :: Source.t() | nil
  def source_by_key(%State{} = state, key),
    do: Enum.find(state.available_sources, &(&1.key == key))

  @doc "Returns the authorized publication with the supplied id, if any."
  @spec publication_by_id(State.t(), integer()) :: Publication.t() | nil
  def publication_by_id(%State{} = state, publication_id) do
    state
    |> available_publications()
    |> Enum.find(&(&1.id == publication_id))
  end

  @doc "Returns the publications authorized through the state's remix sources."
  @spec available_publications(State.t()) :: [Publication.t()]
  def available_publications(%State{} = state) do
    state.available_sources
    |> Enum.flat_map(&Map.values(&1.pinned_publications))
    |> Enum.uniq_by(& &1.id)
  end

  defp publication_by_id!(%Source{} = source, publication_id) do
    Enum.find_value(source.pinned_publications, fn
      {_project_id, %Publication{id: ^publication_id} = publication} -> publication
      _ -> nil
    end) || raise ArgumentError, "project remix source is missing publication #{publication_id}"
  end

  @doc """
  Resolves an authorized source key to the hierarchy instructors may browse.

  Product hierarchies are resolved from the product section rather than the base
  project publication so product-specific removals and hidden resources remain
  authoritative.
  """
  @spec source_hierarchy(String.t(), State.t()) ::
          {:ok, Source.t(), HierarchyNode.t()} | {:error, :unavailable_source}
  def source_hierarchy(source_key, %State{} = state) do
    case source_by_key(state, source_key) do
      %Source{type: :project, publication_id: publication_id} = source ->
        {:ok, source, published_publication_hierarchy(publication_by_id!(source, publication_id))}

      %Source{type: :product, product_id: product_id} = source ->
        case Sections.get_section_by(id: product_id) do
          %Section{} = product ->
            hierarchy =
              product
              |> SectionResourceDepot.get_delivery_resolver_full_hierarchy()
              |> visible_hierarchy()

            {:ok, source, hierarchy}

          nil ->
            {:error, :unavailable_source}
        end

      nil ->
        {:error, :unavailable_source}
    end
  end

  @doc """
  Returns visible pages for an authorized source, excluding resources already in
  the target section when `:exclude_resource_ids` is supplied.
  """
  @spec source_pages(String.t(), State.t(), map()) ::
          {:ok, {non_neg_integer(), [map()]}} | {:error, :unavailable_source}
  def source_pages(source_key, %State{} = state, params) do
    case source_by_key(state, source_key) do
      %Source{type: :project, publication_id: publication_id} ->
        {:ok, Publishing.get_published_pages_by_publication(publication_id, params)}

      %Source{type: :product, product_id: product_id} ->
        {:ok, product_source_pages(product_id, params)}

      nil ->
        {:error, :unavailable_source}
    end
  end

  @doc """
  Converts an item selected from a source to the publication/resource tuple used
  by the existing add and save paths.
  """
  @spec selection_tuple(Source.t(), map()) ::
          {:ok, {pos_integer(), pos_integer()}} | {:error, :unavailable_publication}
  def selection_tuple(%Source{type: :project, publication_id: publication_id}, %{
        resource_id: resource_id
      })
      when is_integer(publication_id) and is_integer(resource_id),
      do: {:ok, {publication_id, resource_id}}

  def selection_tuple(
        source = %Source{type: :product},
        %{project_id: project_id, resource_id: resource_id}
      )
      when is_integer(project_id) and is_integer(resource_id) do
    case selection_tuples(source, [%{project_id: project_id, resource_id: resource_id}]) do
      {:ok, [selection]} -> {:ok, selection}
      {:error, reason} -> {:error, reason}
    end
  end

  def selection_tuple(_source, _item), do: {:error, :unavailable_publication}

  @doc """
  Resolves multiple product items with one visibility query, avoiding one query
  per checked item in the Add Materials picker.
  """
  @spec selection_tuples(Source.t(), [map()]) ::
          {:ok, [{pos_integer(), pos_integer()}]} | {:error, :unavailable_publication}
  def selection_tuples(%Source{type: :project} = source, items) do
    items
    |> Enum.map(&selection_tuple(source, &1))
    |> collect_selection_tuples()
  end

  def selection_tuples(
        %Source{type: :product, product_id: product_id, pinned_publications: pinned_publications},
        items
      ) do
    candidates =
      Enum.map(items, fn
        %{project_id: project_id, resource_id: resource_id}
        when is_integer(project_id) and is_integer(resource_id) ->
          {project_id, resource_id}

        _ ->
          :invalid
      end)

    with false <- :invalid in candidates,
         true <- Enum.all?(candidates, &Map.has_key?(pinned_publications, elem(&1, 0))),
         valid_candidates <- visible_product_resources(product_id, candidates),
         true <- MapSet.new(candidates) == valid_candidates do
      {:ok,
       Enum.map(candidates, fn {project_id, resource_id} ->
         {pinned_publications[project_id].id, resource_id}
       end)}
    else
      _ -> {:error, :unavailable_publication}
    end
  end

  def selection_tuples(_source, _items), do: {:error, :unavailable_publication}

  defp collect_selection_tuples(results) do
    Enum.reduce_while(results, {:ok, []}, fn
      {:ok, selection}, {:ok, selections} -> {:cont, {:ok, [selection | selections]}}
      {:error, reason}, _ -> {:halt, {:error, reason}}
    end)
    |> case do
      {:ok, selections} -> {:ok, Enum.reverse(selections)}
      error -> error
    end
  end

  defp published_publication_hierarchy(%Publication{} = publication) do
    published_resources_by_resource_id = Sections.published_resources_map(publication.id)

    published_revisions_by_resource_id =
      Map.new(published_resources_by_resource_id, fn {resource_id, published_resource} ->
        {resource_id, published_resource.revision}
      end)

    %PublishedResource{revision: root_revision} =
      Map.fetch!(published_resources_by_resource_id, publication.root_resource_id)

    {root_node, _numbering_tracker} =
      AuthoringResolver.hierarchy_node_with_children(
        root_revision,
        publication.project,
        published_revisions_by_resource_id,
        Oli.Resources.Numbering.init_numbering_tracker(),
        0
      )

    root_node
  end

  defp visible_hierarchy(%HierarchyNode{section_resource: %{hidden: true}}), do: nil

  defp visible_hierarchy(%HierarchyNode{} = node) do
    %{node | children: node.children |> Enum.map(&visible_hierarchy/1) |> Enum.reject(&is_nil/1)}
  end

  defp product_source_pages(product_id, params) do
    page_type_id = Oli.Resources.ResourceType.id_for_page()
    text_filter = Map.get(params, :text_search)
    excluded_resource_ids = Map.get(params, :exclude_resource_ids, [])

    visible_resource_ids =
      product_id
      |> visible_product_resource_pairs()
      |> Enum.map(&elem(&1, 1))
      |> MapSet.new()
      |> MapSet.to_list()

    %{limit: limit, offset: offset} = normalize_page_params(params)

    query =
      from(sr in Oli.Delivery.Sections.SectionResource,
        join: spp in SectionsProjectsPublications,
        on: spp.section_id == sr.section_id and spp.project_id == sr.project_id,
        join: pr in PublishedResource,
        on: pr.publication_id == spp.publication_id and pr.resource_id == sr.resource_id,
        join: rev in Revision,
        on: rev.id == pr.revision_id,
        join: pub in Publication,
        on: pub.id == spp.publication_id,
        where:
          sr.section_id == ^product_id and rev.resource_type_id == ^page_type_id and
            rev.deleted != true and (is_nil(sr.hidden) or sr.hidden == false),
        where: sr.resource_id in ^visible_resource_ids,
        select: %{
          id: rev.id,
          title: rev.title,
          graded: rev.graded,
          updated_at: rev.updated_at,
          publication_date: pub.published,
          resource_id: sr.resource_id,
          project_id: sr.project_id
        }
      )
      |> maybe_filter_page_title(text_filter)
      |> maybe_exclude_resources(excluded_resource_ids)
      |> order_product_pages(params)

    total_count = Repo.aggregate(query, :count, :resource_id)

    pages =
      query
      |> maybe_limit(limit)
      |> offset(^offset)
      |> Repo.all()

    {total_count, pages}
  end

  defp maybe_filter_page_title(query, text_filter)
       when is_binary(text_filter) and text_filter != "" do
    where(query, [_sr, _spp, _pr, rev], ilike(rev.title, ^"%#{text_filter}%"))
  end

  defp maybe_filter_page_title(query, _text_filter), do: query

  defp maybe_exclude_resources(query, resource_ids)
       when is_list(resource_ids) and resource_ids != [] do
    where(query, [sr], sr.resource_id not in ^resource_ids)
  end

  defp maybe_exclude_resources(query, _resource_ids), do: query

  defp order_product_pages(query, %{sort_by: sort_by, sort_order: sort_order})
       when sort_by in [:title, :graded, :updated_at] and sort_order in [:asc, :desc] do
    order_by(query, [_sr, _spp, _pr, rev], [{^sort_order, field(rev, ^sort_by)}])
  end

  defp order_product_pages(query, %{sort_by: :publication_date, sort_order: sort_order})
       when sort_order in [:asc, :desc] do
    order_by(query, [_sr, _spp, _pr, _rev, pub], [{^sort_order, pub.published}])
  end

  defp order_product_pages(query, _params), do: query

  defp maybe_limit(query, limit) when is_integer(limit), do: limit(query, ^limit)
  defp maybe_limit(query, _limit), do: query

  defp visible_product_resources(product_id, candidates) do
    visible_resource_pairs = visible_product_resource_pairs(product_id)

    candidates
    |> Enum.filter(&MapSet.member?(visible_resource_pairs, &1))
    |> MapSet.new()
  end

  defp visible_product_resource_pairs(product_id) do
    case Sections.get_section_by(id: product_id) do
      %Section{} = product ->
        product
        |> SectionResourceDepot.get_delivery_resolver_full_hierarchy()
        |> visible_hierarchy()
        |> case do
          %HierarchyNode{} = hierarchy ->
            hierarchy
            |> Hierarchy.flatten_hierarchy()
            |> Enum.map(&{&1.project_id, &1.resource_id})
            |> MapSet.new()

          nil ->
            MapSet.new()
        end

      nil ->
        MapSet.new()
    end
  end

  defp normalize_page_params(params) do
    %{
      limit: params |> Map.get(:limit) |> normalize_limit(),
      offset: params |> Map.get(:offset, 0) |> normalize_offset()
    }
  end

  defp normalize_limit(limit) when is_integer(limit), do: min(max(limit, 1), @max_page_limit)
  defp normalize_limit(_limit), do: @default_page_limit

  defp normalize_offset(offset) when is_integer(offset), do: min(max(offset, 0), @max_page_offset)
  defp normalize_offset(_offset), do: 0

  @doc """
  Select an active container by its uuid. No-op if target is not a container.
  """
  @spec select_active(State.t(), String.t()) :: {:ok, State.t()}
  def select_active(%State{} = state, uuid) do
    node = Hierarchy.find_in_hierarchy(state.hierarchy, uuid)

    if container_revision?(node) do
      {:ok, %State{state | active: node}}
    else
      {:ok, state}
    end
  end

  @doc """
  Reorder a child within the currently active container.
  Indices are 0-based and refer to `state.active.children`.
  """
  @spec reorder(State.t(), non_neg_integer(), integer()) :: {:ok, State.t()}
  def reorder(%State{} = state, source_index, destination_index) do
    active = state.active
    node = Enum.at(active.children, source_index)

    updated =
      Hierarchy.reorder_children(active, node, source_index, destination_index)

    hierarchy =
      state.hierarchy
      |> Hierarchy.find_and_update_node(updated)
      |> Hierarchy.finalize()

    {:ok, %State{state | hierarchy: hierarchy, active: updated, has_unsaved_changes: true}}
  end

  @doc """
  Move a node (by uuid) under destination container (by uuid).
  """
  @spec move(State.t(), String.t(), String.t()) :: {:ok, State.t()}
  def move(%State{} = state, node_uuid, destination_uuid) do
    node = Hierarchy.find_in_hierarchy(state.hierarchy, node_uuid)

    hierarchy =
      state.hierarchy
      |> Hierarchy.move_node(node, destination_uuid)
      |> Hierarchy.finalize()

    active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)
    {:ok, %State{state | hierarchy: hierarchy, active: active, has_unsaved_changes: true}}
  end

  @doc """
  Remove a node from the hierarchy by its uuid.
  """
  @spec remove(State.t(), String.t()) :: {:ok, State.t()}
  def remove(%State{} = state, uuid) do
    hierarchy =
      state.hierarchy
      |> Hierarchy.find_and_remove_node(uuid)
      |> Hierarchy.finalize()

    active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)
    {:ok, %State{state | hierarchy: hierarchy, active: active, has_unsaved_changes: true}}
  end

  @doc """
  Toggle hidden flag for a node by uuid.
  """
  @spec toggle_hidden(State.t(), String.t()) :: {:ok, State.t()}
  def toggle_hidden(%State{} = state, uuid) do
    hierarchy =
      state.hierarchy
      |> Hierarchy.find_and_toggle_hidden(uuid)
      |> Hierarchy.finalize()

    active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)
    {:ok, %State{state | hierarchy: hierarchy, active: active, has_unsaved_changes: true}}
  end

  @doc """
  Add materials described by selection tuples to the active container.
  `selection` is a list of {publication_id, resource_id} tuples.
  `published_resources_by_resource_id_by_pub` is a map of pub_id => %{rid => %PublishedResource{}}.
  """
  @spec add_materials(State.t(), list({pos_integer(), pos_integer()}), map()) ::
          {:ok, State.t()} | {:error, term()}
  def add_materials(%State{} = state, selection, published_resources_by_resource_id_by_pub) do
    publication_index = publication_index(state)

    with :ok <- validate_no_shared_project_resources(state, selection, publication_index) do
      add_validated_materials(
        state,
        selection,
        published_resources_by_resource_id_by_pub,
        publication_index
      )
    end
  end

  @doc """
  Convenience: add materials with publication lookups and canonical ordering preserved
  per original publication hierarchy.
  """
  @spec add_materials(State.t(), list({pos_integer(), pos_integer()})) ::
          {:ok, State.t()} | {:error, term()}
  def add_materials(%State{} = state, selection) do
    unique_pub_ids = add_material_publication_ids(selection)
    pub_by_id = publication_index(state)

    with :ok <- validate_publication_ids_available(unique_pub_ids, pub_by_id),
         :ok <- validate_no_shared_project_resources(state, selection, pub_by_id) do
      published_resources_by_resource_id_by_pub =
        Publishing.get_published_resources_for_publications(unique_pub_ids)

      # Build index per pub for canonical order
      index_by_pub =
        Map.new(unique_pub_ids, fn pub_id ->
          pub = Map.fetch!(pub_by_id, pub_id)
          pr_by_rid = Map.fetch!(published_resources_by_resource_id_by_pub, pub_id)
          {pub_id, build_resource_index_for_pub_map(pr_by_rid, pub)}
        end)

      selection =
        Enum.sort_by(selection, fn {pub_id, rid} ->
          Map.get(index_by_pub[pub_id], rid, :infinity)
        end)

      add_validated_materials(
        state,
        selection,
        published_resources_by_resource_id_by_pub,
        pub_by_id
      )
    end
  end

  defp add_validated_materials(
         %State{} = state,
         selection,
         published_resources_by_resource_id_by_pub,
         pub_by_id
       ) do
    hierarchy =
      state.hierarchy
      |> Hierarchy.add_materials_to_hierarchy(
        state.active,
        selection,
        published_resources_by_resource_id_by_pub
      )
      |> Hierarchy.finalize()

    pinned_project_publications =
      Enum.reduce(selection, state.pinned_project_publications, fn {pub_id, _rid}, acc ->
        case Map.fetch(pub_by_id, pub_id) do
          {:ok, pub} -> Map.put_new(acc, pub.project_id, pub)
          :error -> acc
        end
      end)

    active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)

    {:ok,
     %State{
       state
       | hierarchy: hierarchy,
         active: active,
         has_unsaved_changes: true,
         pinned_project_publications: pinned_project_publications
     }}
  end

  defp validate_no_shared_project_resources(%State{} = _state, [], _pub_by_id), do: :ok

  defp validate_no_shared_project_resources(%State{} = state, selection, pub_by_id) do
    with {:ok, candidate_project_ids} <-
           selection
           |> Enum.map(&elem(&1, 0))
           |> Enum.uniq()
           |> project_ids_for_publication_ids(pub_by_id) do
      existing_project_ids =
        [state.section.base_project_id | Map.keys(state.pinned_project_publications)]
        |> Enum.uniq()

      case shared_project_resource_conflict(candidate_project_ids, existing_project_ids) do
        :selected_projects_share_resources -> {:error, :selected_projects_share_resources}
        :shared_project_resources -> {:error, :shared_project_resources}
        nil -> :ok
      end
    end
  end

  defp project_ids_for_publication_ids(publication_ids, pub_by_id) do
    project_by_publication_id =
      Map.new(pub_by_id, fn {id, publication} -> {id, publication.project_id} end)

    with :ok <- validate_publication_ids_available(publication_ids, project_by_publication_id) do
      project_ids =
        publication_ids
        |> Enum.map(&Map.fetch!(project_by_publication_id, &1))
        |> Enum.uniq()

      {:ok, project_ids}
    end
  end

  defp publication_index(%State{} = state) do
    Map.new(available_publications(state), &{&1.id, &1})
  end

  defp shared_project_resource_conflict([], _existing_project_ids), do: nil

  defp shared_project_resource_conflict(
         [_project_id] = candidate_project_ids,
         existing_project_ids
       ) do
    if existing_projects_share_resources?(candidate_project_ids, existing_project_ids) do
      :shared_project_resources
    end
  end

  defp shared_project_resource_conflict(candidate_project_ids, existing_project_ids) do
    shared_project_resource_conflict_sql = """
    SELECT
      EXISTS (
        SELECT 1
        FROM projects_resources candidate
        JOIN projects_resources other
          ON other.resource_id = candidate.resource_id
        WHERE candidate.project_id = ANY($1)
          AND other.project_id = ANY($1)
          AND candidate.project_id <> other.project_id
      ),
      EXISTS (
        SELECT 1
        FROM projects_resources candidate
        JOIN projects_resources other
          ON other.resource_id = candidate.resource_id
        WHERE candidate.project_id = ANY($1)
          AND other.project_id = ANY($2)
          AND candidate.project_id <> other.project_id
      )
    """

    %{rows: [[selected_projects_conflict?, existing_projects_conflict?]]} =
      Repo.query!(shared_project_resource_conflict_sql, [
        candidate_project_ids,
        existing_project_ids
      ])

    cond do
      selected_projects_conflict? -> :selected_projects_share_resources
      existing_projects_conflict? -> :shared_project_resources
      true -> nil
    end
  end

  defp existing_projects_share_resources?(candidate_project_ids, existing_project_ids) do
    existing_project_conflict_sql = """
    SELECT EXISTS (
      SELECT 1
      FROM projects_resources candidate
      JOIN projects_resources other
        ON other.resource_id = candidate.resource_id
      WHERE candidate.project_id = ANY($1)
        AND other.project_id = ANY($2)
        AND candidate.project_id <> other.project_id
    )
    """

    %{rows: [[existing_projects_conflict?]]} =
      Repo.query!(existing_project_conflict_sql, [
        candidate_project_ids,
        existing_project_ids
      ])

    existing_projects_conflict?
  end

  defp add_material_publication_ids(selection) do
    selection
    |> Enum.map(&elem(&1, 0))
    |> Enum.uniq()
  end

  defp validate_publication_ids_available(publication_ids, pub_by_id) do
    if Enum.any?(publication_ids, &(not Map.has_key?(pub_by_id, &1))) do
      {:error, :unavailable_publication}
    else
      :ok
    end
  end

  defp build_resource_index_for_pub_map(pr_by_rid, pub) do
    root_rev = pr_by_rid[pub.root_resource_id].revision
    hierarchy = Hierarchy.create_hierarchy(root_rev, pr_by_rid)

    hierarchy
    |> Hierarchy.flatten_hierarchy()
    |> Enum.with_index()
    |> Map.new(fn {%{resource_id: rid}, idx} -> {rid, idx} end)
  end

  @doc """
  Create a new container in the active node's children.

  Builds an in-memory draft HierarchyNode with a deterministic negative resource_id.
  No database writes occur — the draft is materialized to real records during save/2.

  Returns updated %State{} with the new container in the hierarchy.
  """
  @spec create_container(State.t(), atom(), String.t(), keyword()) :: State.t()
  def create_container(%State{} = state, _container_type, title, opts \\ []) do
    draft_node =
      ContainerCreation.build_draft(
        state.hierarchy,
        %{id: state.section.base_project_id},
        title,
        opts
      )

    hierarchy =
      state.hierarchy
      |> Hierarchy.find_and_update_node(%{
        state.active
        | children: state.active.children ++ [draft_node]
      })
      |> Hierarchy.finalize()

    active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)

    %State{state | hierarchy: hierarchy, active: active, has_unsaved_changes: true}
  end

  @doc """
  Update editable blueprint-container fields in the in-memory hierarchy.
  Persistence happens during save/2.
  """
  @spec update_container_options(State.t(), String.t(), map()) ::
          {:ok, State.t()} | {:error, term()}
  def update_container_options(%State{} = state, uuid, attrs) do
    case Hierarchy.find_in_hierarchy(state.hierarchy, uuid) do
      %HierarchyNode{} = node ->
        updated_revision =
          node.revision
          |> normalize_revision()
          |> merge_editable_attrs(attrs)

        updated_node = %HierarchyNode{node | revision: updated_revision}

        hierarchy =
          state.hierarchy
          |> Hierarchy.find_and_update_node(updated_node)
          |> Hierarchy.finalize()

        active = Hierarchy.find_in_hierarchy(hierarchy, state.active.uuid)

        {:ok, %State{state | hierarchy: hierarchy, active: active, has_unsaved_changes: true}}

      _ ->
        {:error, :not_found}
    end
  end

  @doc """
  Persist the current hierarchy and pinned publications for the section.
  Materializes any draft containers (negative resource_id) before rebuilding.
  The author parameter identifies who is performing the save (used for revision authorship).
  Returns `{:ok, %Section{}}` or `{:error, reason}`.
  """
  @spec save(State.t(), Author.t() | nil) :: {:ok, Section.t()} | {:error, term()}
  def save(%State{} = state, author \\ nil) do
    %Section{base_project: base_project} = section = Repo.preload(state.section, :base_project)

    Repo.transaction(fn ->
      with {:ok, hierarchy} <-
             ContainerCreation.materialize(state.hierarchy, base_project, author),
           {:ok, hierarchy} <-
             persist_blueprint_container_edits(
               hierarchy,
               state.previous_hierarchy,
               section,
               base_project,
               author
             ),
           {:ok, _} <-
             rebuild_section_curriculum(
               section,
               Hierarchy.finalize(hierarchy),
               state.pinned_project_publications
             ) do
        section.id
      else
        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, section_id} -> {:ok, Sections.get_section!(section_id)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp container_revision?(nil), do: false

  defp container_revision?(%{revision: rev}) when is_map(rev) do
    rev.resource_type_id == Oli.Resources.ResourceType.id_for_container()
  end

  defp container_revision?(_), do: false

  defp persist_blueprint_container_edits(
         %HierarchyNode{} = hierarchy,
         %HierarchyNode{} = previous_hierarchy,
         %Section{} = _section,
         base_project,
         %Author{id: author_id}
       ) do
    previous_by_resource_id =
      previous_hierarchy
      |> Hierarchy.flatten_hierarchy()
      |> Map.new(&{&1.resource_id, &1})

    edited_nodes = edited_blueprint_nodes(hierarchy, previous_by_resource_id)

    if edited_nodes == [] do
      {:ok, hierarchy}
    else
      case Enum.reduce_while(edited_nodes, %{}, fn %HierarchyNode{} = node, updated_nodes ->
             previous_node = Map.fetch!(previous_by_resource_id, node.resource_id)
             previous_revision = Repo.get!(Revision, previous_node.revision.id)

             attrs = editable_attrs(node.revision)

             case Resources.create_revision_from_previous(
                    previous_revision,
                    Map.put(attrs, :author_id, author_id)
                  ) do
               {:ok, revision} ->
                 now = DateTime.utc_now(:second)

                 from(pr in PublishedResource,
                   join: pub in Publication,
                   on: pr.publication_id == pub.id,
                   where:
                     pub.project_id == ^base_project.id and
                       pr.resource_id == ^revision.resource_id
                 )
                 |> Repo.update_all(set: [revision_id: revision.id, updated_at: now])

                 {:cont,
                  Map.put(updated_nodes, node.uuid, %HierarchyNode{node | revision: revision})}

               {:error, reason} ->
                 {:halt, {:error, reason}}
             end
           end) do
        {:error, reason} ->
          {:error, reason}

        updated_nodes ->
          updated_hierarchy =
            Hierarchy.find_and_update_nodes(hierarchy, Map.values(updated_nodes))

          {:ok, Hierarchy.finalize(updated_hierarchy)}
      end
    end
  end

  defp persist_blueprint_container_edits(
         %HierarchyNode{} = hierarchy,
         %HierarchyNode{} = previous_hierarchy,
         _section,
         _base_project,
         nil
       ) do
    previous_by_resource_id =
      previous_hierarchy
      |> Hierarchy.flatten_hierarchy()
      |> Map.new(&{&1.resource_id, &1})

    if edited_blueprint_nodes(hierarchy, previous_by_resource_id) == [] do
      {:ok, hierarchy}
    else
      {:error, :author_required_for_blueprint_container_edit}
    end
  end

  defp edited_blueprint_nodes(%HierarchyNode{} = hierarchy, previous_by_resource_id)
       when is_map(previous_by_resource_id) do
    hierarchy
    |> Hierarchy.flatten_hierarchy()
    |> Enum.filter(fn
      %HierarchyNode{resource_id: resource_id, revision: revision} = node when resource_id > 0 ->
        blueprint_container?(node) and
          Map.has_key?(previous_by_resource_id, resource_id) and
          editable_attrs(revision) !=
            editable_attrs(previous_by_resource_id[resource_id].revision)

      _ ->
        false
    end)
  end

  defp edited_blueprint_nodes(_hierarchy, _previous_hierarchy), do: []

  defp blueprint_container?(%HierarchyNode{revision: revision}) do
    revision.resource_type_id == Oli.Resources.ResourceType.id_for_container() and
      revision.resource_scope == :blueprint
  end

  defp editable_attrs(revision) do
    revision = normalize_revision(revision)

    %{
      title: revision.title,
      intro_content: revision.intro_content,
      intro_video: revision.intro_video,
      poster_image: revision.poster_image
    }
  end

  defp merge_editable_attrs(revision, attrs) do
    %Revision{} = revision = normalize_revision(revision)

    %Revision{
      revision
      | title: Map.get(attrs, "title", Map.get(attrs, :title, revision.title)),
        intro_content:
          Map.get(attrs, "intro_content", Map.get(attrs, :intro_content, revision.intro_content)),
        intro_video:
          Map.get(attrs, "intro_video", Map.get(attrs, :intro_video, revision.intro_video)),
        poster_image:
          Map.get(attrs, "poster_image", Map.get(attrs, :poster_image, revision.poster_image))
    }
  end

  defp normalize_revision(%Revision{} = revision), do: revision

  defp normalize_revision(revision) when is_map(revision) do
    struct(
      Revision,
      Map.take(revision, [
        :id,
        :resource_id,
        :resource_type_id,
        :resource_scope,
        :slug,
        :title,
        :intro_content,
        :intro_video,
        :poster_image,
        :graded
      ])
    )
  end

  defp rebuild_section_curriculum(
         %Section{} = section,
         %HierarchyNode{} = hierarchy,
         pinned_project_publications
       ) do
    case Sections.rebuild_section_curriculum(section, hierarchy, pinned_project_publications) do
      {:ok, _} = ok ->
        ok

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end
end
