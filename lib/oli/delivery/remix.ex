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

  alias Oli.Delivery.Remix.State
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Hierarchy
  alias Oli.Publishing
  alias Oli.Publishing.DeliveryResolver
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
  Persist the current hierarchy and pinned publications for the section.
  Returns {:ok, %Section{}} or {:error, {:rebuild_failed, step, reason}}.
  """
  @spec save(State.t()) :: {:ok, Section.t()} | {:error, term()}
  def save(%State{} = state) do
    case Sections.rebuild_section_curriculum(
           state.section,
           state.hierarchy,
           state.pinned_project_publications
         ) do
      {:ok, _multi} -> {:ok, Sections.get_section!(state.section.id)}
      {:error, step, reason, _changes} -> {:error, {:rebuild_failed, step, reason}}
    end
  end

  defp container_revision?(nil), do: false

  defp container_revision?(%{revision: rev}) when is_map(rev) do
    rev.resource_type_id == Oli.Resources.ResourceType.id_for_container()
  end

  defp container_revision?(_), do: false
end
