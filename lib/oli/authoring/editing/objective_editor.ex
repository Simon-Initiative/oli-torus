defmodule Oli.Authoring.Editing.ObjectiveEditor do

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course.Project
  alias Oli.Repo
  alias Oli.Authoring.Broadcaster
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Publishing.AuthoringResolver

  import Oli.Utils

  def add_new(attrs, %Author{} = author, %Project{} = project, container_slug \\ nil) do

    attrs = Map.merge(attrs, %{
      author_id: author.id,
      resource_type_id: Oli.Resources.ResourceType.get_id_by_type("objective")
    })

    Repo.transaction(fn ->

      with {:ok, %{resource: resource, revision: revision}} <- Oli.Authoring.Course.create_and_attach_resource(project, attrs),
          publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
          {:ok, mapping} <- Publishing.upsert_published_resource(publication, revision),
          {:ok, container} <- maybe_append_to_container(container_slug, publication, revision, project.slug, author)
      do

        Broadcaster.broadcast_resource(revision, project.slug)

        {:ok,
          %{
            resource: resource,
            revision: revision,
            project: project,
            mapping: mapping,
            container: container
          }
        }
      else
        error -> Repo.rollback(error)
      end

    end)
  end

  def edit(revision_slug, attrs, %Author{} = author, %Project{} = project) do

    attrs = Map.merge(attrs, %{
      author_id: author.id,
    })

    Repo.transaction(fn ->

      with {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
          publication <- Publishing.get_unpublished_publication_by_slug!(project.slug),
          {:ok, revision} <- Publishing.get_published_revision(publication.id, resource.id) |> trap_nil(),
          {:ok, new_revision} <- Resources.create_revision_from_previous(revision, attrs),
          {:ok, _} <- Publishing.upsert_published_resource(publication, new_revision)
      do

        Broadcaster.broadcast_revision(new_revision, project.slug)

        {:ok, new_revision}
      else
        error -> Repo.rollback(error)
      end

    end)
  end


  def detach_objective(revision_slug, %Project{} = project, author) do

    case preview_objective_detatchment(revision_slug, project) do
      %{attachments: {[], []}} -> []

      %{attachments: {pages, activities}, locked_by: locked_by, parent_pages: parent_pages} ->

        # detach from all non-locked pages
        Enum.filter(pages, fn %{resource_id: resource_id} -> !Map.has_key?(locked_by, resource_id) end)
        |> Enum.each(fn %{slug: slug} ->
          detach_from_page(revision_slug, slug, project.slug, author)
        end)

        # detach from all non-locked activities. Locked activities are those activities
        # whose parent page is locked
        Enum.filter(activities, fn %{resource_id: resource_id} -> !Map.has_key?(locked_by, Map.get(parent_pages, resource_id)) end)
        |> Enum.each(fn %{slug: slug, resource_id: resource_id} ->
          page = AuthoringResolver.from_resource_id(project.slug, Map.get(parent_pages, resource_id))
          detach_from_activity(revision_slug, page.slug, slug, project.slug, author)
        end)

    end

  end

  defp detach_from_page(objective_slug, page_slug, project_slug, author) do

    case PageEditor.acquire_lock(project_slug, page_slug, author.email) do
      {:acquired} ->

        {:ok, %{objectives: objectives}} = PageEditor.create_context(project_slug, page_slug, author)

        update = %{"objectives" =>
          %{"attached" => Enum.filter(Map.get(objectives, :attached), fn s -> s != objective_slug end)}}

        case PageEditor.edit(project_slug, page_slug, author.email, update) do
          {:ok, _} ->
            PageEditor.release_lock(project_slug, page_slug, author.email)
            true

          _ -> false
        end

      _ -> false
    end

  end

  defp detach_from_activity(objective_slug, page_slug, activity_slug, project_slug, author) do

    case PageEditor.acquire_lock(project_slug, page_slug, author.email) do
      {:acquired} ->
        {:ok, %{objectives: objectives}} = ActivityEditor.create_context(project_slug, page_slug, activity_slug, author)

        objective = AuthoringResolver.from_revision_slug(project_slug, objective_slug)

        update = %{"objectives" => Enum.reduce(objectives, %{}, fn {p, a}, m ->
            Map.put(m, p, Enum.filter(a, fn s -> s != objective.slug end))
          end)
        }

        ActivityEditor.edit(project_slug, page_slug, activity_slug, author.email, update)
        PageEditor.release_lock(project_slug, page_slug, author.email)
    end

  end

  @spec preview_objective_detatchment(binary, Oli.Authoring.Course.Project.t()) :: %{
          attachments: {any, any},
          locked_by: any,
          parent_pages: any
        }
  def preview_objective_detatchment(revision_slug, %Project{} = project) do

    resource = Resources.get_resource_from_slug(revision_slug)
    publication = Publishing.get_unpublished_publication_by_slug!(project.slug)

    # find all attachments
    case Publishing.find_objective_attachments(resource.id, publication.id) do

      # if no attachments
      [] -> %{attachments: {[], []}, locked_by: %{}, parent_pages: %{}}

      # otherwise we need to see which attachments are currently locked for edit
      attachments ->

        # partition the attachments between pages and activities
        {pages, activities} = partition_attachments(attachments)

        # activites can be duplicatd if more than one part has an attachment, so
        # dedupe for the purposes of detachment
        distinct_activities = dedupe_activities(activities)

        # for those activities, determine which pages they exist in and combine
        # that set of pages with the set of pages that contain the objective
        # directly attached to it
        {parent_pages, unified_pages} = case distinct_activities do
          [] -> {%{}, MapSet.new(Enum.map(pages, fn p -> p.resource_id end))}
          a ->

            activity_ids = Enum.map(a, fn e -> Map.get(e, :resource_id) end)
            parent_pages = Publishing.determine_parent_pages(activity_ids, publication.id)
            unified_pages = unify_pages(parent_pages, pages)
            {parent_pages, unified_pages}
        end

        # now we can determine for all pages, which users might be currently editing
        locked_by = Publishing.retrieve_lock_info(MapSet.to_list(unified_pages), publication.id)
        |> Enum.reduce(%{}, fn mapping, m ->
          case Oli.Authoring.Locks.expired_or_empty?(mapping) do
            true -> m
            false -> Map.put(m, mapping.resource_id, mapping)
          end
        end)

        %{attachments: {pages, distinct_activities}, locked_by: locked_by, parent_pages: parent_pages}

    end

  end

  defp partition_attachments(attachments) do
    Enum.reduce(attachments, {[], []}, fn e, {p, a} ->
      case e.part do
        "attached" -> {p ++ [e], a}
        _ -> {p, a ++ [e]}
      end
    end)
  end

  defp dedupe_activities(activities) do
    {deduped, _} = Enum.reduce(activities, {[], MapSet.new()}, fn e, {a, m} ->
      case MapSet.member?(m, e.resource_id) do
        true -> {a, m}
        false -> {a ++ [e], MapSet.put(m, e.resource_id)}
      end
    end)
    deduped
  end

  defp unify_pages(parent_pages, pages) do
    Enum.map(parent_pages, fn {_, id} -> id end)
    |> MapSet.new()
    |> MapSet.union(MapSet.new(Enum.map(pages, fn p -> p.resource_id end)))
  end

  @spec maybe_append_to_container(nil | binary, any, any, any, any) ::
          {:error, {any}} | {:ok, atom | %{id: any, resource_id: integer}}
  defp maybe_append_to_container(container_slug, publication, revision_to_attach, project_slug, author) do

    case container_slug do
      nil -> {:ok, nil}
      "" -> {:ok, nil}
      slug -> append_to_container(slug, publication, revision_to_attach, project_slug, author)
    end

  end

  defp append_to_container(container_slug, publication, revision_to_attach, project_slug, author) do

    with {:ok, resource} <- Resources.get_resource_from_slug(container_slug) |> trap_nil(),
        {:ok, revision} <- Publishing.get_published_revision(publication.id, resource.id) |> trap_nil()
    do

      attrs = %{
        children: [revision_to_attach.resource_id | revision.children],
        author_id: author.id
      }
      {:ok, next} = Oli.Resources.create_revision_from_previous(revision, attrs)
      {:ok, _} = Publishing.upsert_published_resource(publication, next)

      Broadcaster.broadcast_revision(next, project_slug)

      {:ok, next}
    else
      error -> error
    end

  end

  def fetch_objective_mappings(project) do

    publication = Publishing.get_unpublished_publication_by_slug!(project.slug)
    Publishing.get_objective_mappings_by_publication(publication.id)
  end

end

