defmodule Oli.Delivery.Sections.Audited.Remix do
  @moduledoc false
  # The save of a remix: moved here from `Oli.Delivery.Remix.save/2`, which had no actor.
  #
  # The section is locked first, with the same lock the curriculum rebuild takes, and the
  # persisted curriculum is read before and after the save. Each curriculum entry (a unit,
  # module, section, or page reachable from the root) whose parent, position, visibility,
  # numbering, or source publication changed records one `section_remix_saved`, matched by
  # resource: an added entry has no before-state and a removed one no after-state.

  import Ecto.Query, only: [from: 2]

  alias Oli.Auditing.{Changes, Context, EntityId}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Delivery.Hierarchy
  alias Oli.Delivery.Remix
  alias Oli.Delivery.Remix.{ContainerCreation, State}
  alias Oli.Delivery.Sections
  alias Oli.Delivery.DepotCoordinator
  alias Oli.Delivery.Sections.{Section, SectionCache, SectionResource, SectionResourceDepot}
  alias Oli.Delivery.Sections.SectionResourceMigration
  alias Oli.Delivery.Sections.SectionsProjectsPublications
  alias Oli.Delivery.Sections.Audited.Support
  alias Oli.Lti.PlatformExternalTools
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.Revision

  def save(%Context{} = context, %State{} = state, author) do
    case Repo.in_transaction?() do
      true -> {:error, :nested_transaction}
      false -> run(context, state, author)
    end
  end

  defp run(context, state, author) do
    %Section{base_project: base_project} = section = Repo.preload(state.section, :base_project)

    Repo.transaction(fn ->
      SectionResourceMigration.lock_section!(section.id)
      before = curriculum(section.id)

      with {:ok, hierarchy} <-
             ContainerCreation.materialize(state.hierarchy, base_project, author),
           {:ok, hierarchy} <-
             Remix.persist_blueprint_container_edits(
               hierarchy,
               state.previous_hierarchy,
               section,
               base_project,
               author
             ),
           {:ok, _} <-
             rebuild_curriculum(section, hierarchy, state.pinned_project_publications),
           {:ok, _} <-
             PlatformExternalTools.initialize_remixed_deep_links(
               section.id,
               Remix.remixed_activity_sources(hierarchy, state.material_sources)
             ),
           :ok <- record(context, section.id, before, curriculum(section.id)) do
        section.id
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, section_id} ->
        # The rebuild clears these inside the transaction; a read before the commit could have
        # cached the previous curriculum again
        SectionCache.clear(section.slug)
        DepotCoordinator.clear_synchronously(SectionResourceDepot.depot_desc(), section_id)
        {:ok, Sections.get_section!(section_id)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp rebuild_curriculum(section, hierarchy, pinned_project_publications) do
    case Sections.rebuild_section_curriculum(
           section,
           Hierarchy.finalize(hierarchy),
           pinned_project_publications
         ) do
      {:ok, _} = ok -> ok
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  @doc """
  The persisted curriculum of the section with `section_id`, by resource ID: each entry
  reachable from the root with its parent resource, 1-based position among its siblings,
  visibility, numbering, and source publication, plus its title and slug for the snapshot.
  """
  def curriculum(section_id) do
    root_id =
      Repo.one(from(s in Section, where: s.id == ^section_id, select: s.root_section_resource_id))

    rows =
      from(sr in SectionResource,
        left_join: rev in Revision,
        on: rev.id == sr.revision_id,
        where: sr.section_id == ^section_id,
        select: %{
          id: sr.id,
          resource_id: sr.resource_id,
          project_id: sr.project_id,
          children: sr.children,
          hidden: sr.hidden,
          numbering_index: sr.numbering_index,
          title: coalesce(sr.title, rev.title),
          slug: sr.slug
        }
      )
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    publications =
      from(spp in SectionsProjectsPublications,
        where: spp.section_id == ^section_id,
        select: {spp.project_id, spp.publication_id}
      )
      |> Repo.all()
      |> Map.new()

    case Map.fetch(rows, root_id) do
      {:ok, root} ->
        {_visited, entries} = collect(root, rows, publications, MapSet.new([root_id]), %{})
        entries

      :error ->
        %{}
    end
  end

  # Walks the children of `parent` depth first; `visited` guards against a malformed tree.
  defp collect(parent, rows, publications, visited, entries) do
    (parent.children || [])
    |> Enum.with_index(1)
    |> Enum.reduce({visited, entries}, fn {child_id, position}, {visited, entries} ->
      case {Map.fetch(rows, child_id), MapSet.member?(visited, child_id)} do
        {{:ok, child}, false} ->
          entry = %{
            parent: parent.resource_id,
            position: position,
            hidden: child.hidden,
            numbering_index: child.numbering_index,
            source_publication_id: Map.get(publications, child.project_id),
            title: child.title,
            slug: child.slug
          }

          collect(
            child,
            rows,
            publications,
            MapSet.put(visited, child_id),
            Map.put_new(entries, child.resource_id, entry)
          )

        _missing_or_visited ->
          {visited, entries}
      end
    end)
  end

  defp record(context, section_id, before, after_save) do
    resource_ids = Enum.uniq(Map.keys(before) ++ Map.keys(after_save))

    changed =
      Enum.flat_map(resource_ids, fn resource_id ->
        old = Map.get(before, resource_id)
        new = Map.get(after_save, resource_id)

        case Changes.diff(old, new, Fields.remix()) do
          changes when changes == %{} -> []
          changes -> [{resource_id, old, new, changes}]
        end
      end)

    labels = publication_labels(changed)

    proposals =
      Enum.map(changed, fn {resource_id, old, new, changes} ->
        %{
          event_type: :section_remix_saved,
          entity:
            {:curriculum_entry, EntityId.compose(section: section_id, resource: resource_id),
             Map.take(new || old, [:title, :slug])},
          scope: %{section_id: section_id, resource_id: resource_id},
          event_key: "remix:#{resource_id}:saved",
          refs: source_refs(old, new, changes, labels),
          changes: changes
        }
      end)

    Support.record_many(context, proposals)
  end

  # The publication an entry comes from, when it changed or the entry was added.
  defp source_refs(_old, new, %{"source_publication_id" => _}, labels)
       when is_map(new) and is_integer(new.source_publication_id) do
    id = new.source_publication_id
    [%{role: :source, type: :publication, id: id, label: Map.get(labels, id)}]
  end

  defp source_refs(_old, _new, _changes, _labels), do: []

  # The labels of the publications that `source_refs/4` names: those of entries whose source
  # changed or that were added.
  defp publication_labels(changed) do
    changed
    |> Enum.flat_map(fn {_resource_id, _old, new, changes} ->
      case {new, Map.has_key?(changes, "source_publication_id")} do
        {%{source_publication_id: id}, true} when is_integer(id) -> [id]
        _no_source_ref -> []
      end
    end)
    |> Enum.uniq()
    |> labels()
  end

  defp labels([]), do: %{}

  defp labels(ids) do
    from(p in Publication,
      where: p.id in ^ids,
      select: {p.id, p.edition, p.major, p.minor}
    )
    |> Repo.all()
    |> Map.new(fn {id, edition, major, minor} -> {id, "#{edition}.#{major}.#{minor}"} end)
  end
end
