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
  alias Oli.Delivery.Remix.State
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing.{PublishedResource, Publications.Publication}
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Accounts.{User, Author}
  alias Oli.Repo

  @doc """
  Initialize Remix state from a section and an actor (Author or User).

  Returns {:ok, %State{}} on success.
  """
  @spec init(Section.t(), User.t() | Author.t()) :: {:ok, State.t()} | {:error, term()}
  def init(%Section{} = section, %User{} = user) do
    section = Repo.preload(section, :institution)

    available_publications =
      Publishing.retrieve_visible_publications(user, section.institution)
      |> pin_precedence(section)

    build_initial_state(section, available_publications)
  end

  def init(%Section{} = section, %Author{} = author) do
    section = Repo.preload(section, :institution)

    available_publications =
      Publishing.available_publications(author, section.institution)
      |> pin_precedence(section)

    build_initial_state(section, available_publications)
  end

  defp pin_precedence(publications, %Section{id: section_id}) do
    pinned = Sections.get_pinned_project_publications(section_id)

    Enum.map(publications, fn pub -> Map.get(pinned, pub.project_id, pub) end)
  end

  @doc """
  Initialize Remix state for open-and-free context using all available publications.
  """
  @spec init_open_and_free(Section.t()) :: {:ok, State.t()} | {:error, term()}
  def init_open_and_free(%Section{} = section) do
    section = Repo.preload(section, :institution)
    available_publications = Publishing.all_available_publications() |> pin_precedence(section)
    build_initial_state(section, available_publications)
  end

  defp build_initial_state(section, available_publications) do
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)

    {:ok,
     %State{
       section: section,
       hierarchy: hierarchy,
       previous_hierarchy: hierarchy,
       active: hierarchy,
       pinned_project_publications: Sections.get_pinned_project_publications(section.id),
       available_publications: available_publications
     }}
  end

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
  @spec add_materials(State.t(), list({pos_integer(), pos_integer()}), map()) :: {:ok, State.t()}
  def add_materials(%State{} = state, selection, published_resources_by_resource_id_by_pub) do
    hierarchy =
      state.hierarchy
      |> Hierarchy.add_materials_to_hierarchy(
        state.active,
        selection,
        published_resources_by_resource_id_by_pub
      )
      |> Hierarchy.finalize()

    # update pinned publications similar to LiveView behavior
    pub_by_id = Map.new(state.available_publications, &{&1.id, &1})

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

  @doc """
  Convenience: add materials with publication lookups and canonical ordering preserved
  per original publication hierarchy.
  """
  @spec add_materials(State.t(), list({pos_integer(), pos_integer()})) :: {:ok, State.t()}
  def add_materials(%State{} = state, selection) do
    unique_pub_ids = selection |> Enum.map(&elem(&1, 0)) |> Enum.uniq()
    pub_by_id = Map.new(state.available_publications, &{&1.id, &1})

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

    add_materials(state, selection, published_resources_by_resource_id_by_pub)
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

    with {:ok, hierarchy} <- ContainerCreation.materialize(state.hierarchy, base_project, author),
         {:ok, hierarchy} <-
           persist_blueprint_container_edits(
             hierarchy,
             state.previous_hierarchy,
             section,
             base_project,
             author
           ) do
      hierarchy = Hierarchy.finalize(hierarchy)

      Sections.rebuild_section_curriculum(section, hierarchy, state.pinned_project_publications)

      {:ok, Sections.get_section!(section.id)}
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
    edited_nodes = edited_blueprint_nodes(hierarchy, previous_hierarchy)

    if edited_nodes == [] do
      {:ok, hierarchy}
    else
      Repo.transaction(fn ->
        Enum.reduce_while(edited_nodes, %{}, fn %HierarchyNode{} = node, updated_nodes ->
          previous_node =
            Hierarchy.find_in_hierarchy(previous_hierarchy, fn n ->
              n.resource_id == node.resource_id
            end)

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
                  pub.project_id == ^base_project.id and pr.resource_id == ^revision.resource_id
              )
              |> Repo.update_all(set: [revision_id: revision.id, updated_at: now])

              {:cont,
               Map.put(updated_nodes, node.uuid, %HierarchyNode{node | revision: revision})}

            {:error, reason} ->
              {:halt, Repo.rollback(reason)}
          end
        end)
      end)
      |> case do
        {:ok, updated_nodes} ->
          updated_hierarchy =
            Hierarchy.find_and_update_nodes(hierarchy, Map.values(updated_nodes))

          {:ok, Hierarchy.finalize(updated_hierarchy)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp persist_blueprint_container_edits(
         %HierarchyNode{} = hierarchy,
         _previous_hierarchy,
         _section,
         _base_project,
         nil
       ) do
    if edited_blueprint_nodes(hierarchy, nil) == [] do
      {:ok, hierarchy}
    else
      {:error, :author_required_for_blueprint_container_edit}
    end
  end

  defp edited_blueprint_nodes(%HierarchyNode{} = hierarchy, %HierarchyNode{} = previous_hierarchy) do
    previous_by_resource_id =
      previous_hierarchy
      |> Hierarchy.flatten_hierarchy()
      |> Map.new(&{&1.resource_id, &1})

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
end
