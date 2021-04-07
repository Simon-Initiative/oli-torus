defmodule Oli.Authoring.Editing.PageEditor do
  @moduledoc """
  This module provides content editing facilities for pages.

  """
  import Oli.Authoring.Editing.Utils
  alias Oli.Authoring.{Locks, Course}
  alias Oli.Resources.Revision
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Activities
  alias Oli.Accounts
  alias Oli.Repo
  alias Oli.Rendering
  alias Oli.Activities.Transformers
  alias Oli.Activities.State.ActivityState
  alias Oli.Authoring.Broadcaster
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Activities

  import Ecto.Query, warn: false

  @doc """
  Attempts to process an edit for a resource specified by a given
  project and revision slug, for the author specified by email.

  The update parameter is a map containing key-value pairs of the
  attributes of a resource Revision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%Revision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, %Revision{}}` when the edit processes successfully the
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t(), String.t(), String.t(), %{}) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, {String.t(), Calendar.naive_datetime()}}}
          | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, author_email, update) do
    result =
      with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
           {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project),
           {:ok, publication} <-
             Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
           {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
           {:ok, converted_update} <- convert_to_activity_ids(update) do
        Repo.transaction(fn ->
          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired the lock, we must first create a new revision
            {:acquired} ->
              get_latest_revision(publication, resource)
              |> resurrect_or_delete_activity_references(converted_update, project.slug)
              |> create_new_revision(publication, resource, author.id)
              |> update_revision(converted_update, project.slug)
              |> possibly_release_lock(project, publication, resource, author, update)

            # A successful lock update means we can safely edit the existing revision
            {:updated} ->
              get_latest_revision(publication, resource)
              |> resurrect_or_delete_activity_references(converted_update, project.slug)
              |> maybe_create_new_revision(publication, resource, author.id, converted_update)
              |> update_revision(converted_update, project.slug)
              |> possibly_release_lock(project, publication, resource, author, update)

            # error or not able to lock results in a failed edit
            result ->
              Repo.rollback(result)
          end
        end)
      else
        error -> error
      end

    case result do
      {:ok, {revision, activity_revisions}} ->
        Enum.each(activity_revisions ++ [revision], fn r ->
          Broadcaster.broadcast_revision(r, project_slug)
        end)

        {:ok, revision}

      e ->
        e
    end
  end

  defp possibly_release_lock(previous, project, publication, resource, author, update) do
    if Map.get(update, "releaseLock", false) do
      Locks.release(project.slug, publication.id, resource.id, author.id)
    end

    previous
  end

  @doc """
  Attempts to lock a resource for editing.

  Not acquiring the lock here isn't considered a failure, as it is
  an expected condition that a user could encounter.

  Returns:

  .`{:acquired}` when the lock is acquired
  .`{:lock_not_acquired, user_email}` if the lock could not be acquired
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec acquire_lock(String.t(), String.t(), String.t()) ::
          {:acquired}
          | {:lock_not_acquired, {String.t(), Calendar.naive_datetime()}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def acquire_lock(project_slug, revision_slug, author_email) do
    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      case Locks.acquire(project.slug, publication.id, resource.id, author.id) do
        # If we reacquired the lock, we must first create a new revision
        {:acquired} -> {:acquired}
        # error or not able to lock results in a failed edit
        {:lock_not_acquired, {locked_by, locked_at}} -> {:lock_not_acquired, {locked_by, locked_at}}
        error -> {:error, error}
      end
    else
      error -> error
    end
  end

  @doc """
  Attempts to release an edit lock.

  Returns:

  .`{:ok, {:released}}` when the lock is acquired
  .`{:error, {:error}` if an unknown error encountered
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  """
  @spec release_lock(String.t(), String.t(), String.t()) ::
          {:ok, {:released}}
          | {:error, {:not_found}}
          | {:error, {:not_authorized}}
          | {:error, {:error}}
  def release_lock(project_slug, revision_slug, author_email) do
    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      case Locks.release(project.slug, publication.id, resource.id, author.id) do
        {:error} -> {:error, {:error}}
        _ -> {:ok, {:released}}
      end
    else
      error -> error
    end
  end

  @doc """
  Creates the context necessary to power a client side resource editor
  for a specific resource / revision.
  """
  def create_context(project_slug, revision_slug, author) do
    editor_map = Activities.create_registered_activity_map(project_slug)

    with {:ok, publication} <-
           Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, %{content: content} = revision} <-
           AuthoringResolver.from_revision_slug(project_slug, revision_slug) |> trap_nil(),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_with_parent_reference} <-
           construct_parent_references(objectives) |> trap_nil(),
         {:ok, activities} <- create_activities_map(project_slug, publication.id, content) do
      {:ok,
       create(
         publication.id,
         revision,
         project_slug,
         revision_slug,
         author,
         objectives_with_parent_reference,
         revision.objectives,
         activities,
         editor_map
       )}
    else
      _ -> {:error, :not_found}
    end
  end

  def render_page_html(project_slug, revision_slug, author, options \\ []) do
    with {:ok, publication} <-
           Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
         {:ok, %{content: content} = _revision} <-
           get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, activities} <- create_activity_summary_map(publication.id, content),
         render_context <- %Rendering.Context{
           user: author,
           preview: Keyword.get(options, :preview, false),
           activity_map: activities
         } do
      Rendering.Page.render(render_context, content["model"], Rendering.Page.Html)
    else
      _ -> {:error, :not_found}
    end
  end

  defp create_activity_summary_map(publication_id, %{"model" => content}) do
    # Now see if we even have any activities that need to be mapped
    found_activities =
      Enum.filter(content, fn c -> Map.get(c, "type") == "activity-reference" end)
      |> Enum.map(fn c -> Map.get(c, "activity_id") end)

    if length(found_activities) != 0 do
      # get a view of all current registered activity types
      registrations = Activities.list_activity_registrations()
      reg_map = Enum.reduce(registrations, %{}, fn r, m -> Map.put(m, r.id, r) end)

      # find the published revisions for these activities, and convert them
      # to a form suitable for front-end consumption
      {:ok,
       Publishing.get_published_activity_revisions(publication_id, found_activities)
       |> Enum.map(fn %Revision{
                        resource_id: resource_id,
                        activity_type_id: activity_type_id,
                        content: content,
                        graded: graded
                      } ->
         # To support 'test mode' in the editor, we give the editor an initial transformed
         # version of the model that it can immediately use for display purposes. If it fails
         # to transform, nil will be handled by the client and the raw model will be used
         # instead
         transformed =
           case Transformers.apply_transforms(content) do
             {:ok, t} -> t
             _ -> nil
           end

         # the activity type this revision pertains to
         type = Map.get(reg_map, activity_type_id)

         state = ActivityState.create_preview_state(transformed)

         %ActivitySummary{
           id: resource_id,
           model: ActivityContext.prepare_model(transformed, prune: false),
           state: ActivityContext.prepare_state(state),
           delivery_element: type.delivery_element,
           script: type.delivery_script,
           graded: graded
         }
       end)
       |> Enum.reduce(%{}, fn summary, acc -> Map.put(acc, summary.id, summary) end)}
    else
      {:ok, %{}}
    end
  end

  # From the array of maps found in a resource revision content, produce a
  # map of the content of the activity revisions that pertain to the
  # current publication
  defp create_activities_map(_, publication_id, %{"model" => content}) do
    # Now see if we even have any activities that need to be mapped
    found_activities =
      Enum.filter(content, fn c -> Map.get(c, "type") == "activity-reference" end)
      |> Enum.map(fn c -> Map.get(c, "activity_id") end)

    if length(found_activities) != 0 do
      # create a mapping of registered activity type id to the registered activity slug
      id_to_slug =
        Activities.list_activity_registrations()
        |> Enum.reduce(%{}, fn e, m -> Map.put(m, Map.get(e, :id), Map.get(e, :slug)) end)

      # find the published revisions for these activities, and convert them
      # to a form suitable for front-end consumption
      {:ok,
       Publishing.get_published_activity_revisions(publication_id, found_activities)
       |> Enum.map(fn %Revision{
                        activity_type_id: activity_type_id,
                        objectives: objectives,
                        slug: slug,
                        content: content
                      } ->
         %{
           type: "activity",
           typeSlug: Map.get(id_to_slug, activity_type_id),
           activitySlug: slug,
           model: content,
           objectives: objectives
         }
       end)
       |> Enum.reduce(%{}, fn e, m -> Map.put(m, Map.get(e, :activitySlug), e) end)}
    else
      {:ok, %{}}
    end
  end

  # Look to see what activity references this change would add or remove and
  # ensure that the revision backing that activity has its 'deleted' flag
  # set appropriately.  This allows the client to insert an activity reference,
  # and remove it, then bring it back using 'Undo' - all while keeping the
  # deleted state of the activity revision correct.
  defp resurrect_or_delete_activity_references(revision, change, project_slug) do
    if Map.get(change, :deleted) do
      content = Map.get(revision.content, "model")
      deletions = activity_references(content)
      delete_activity_references(project_slug, revision, MapSet.new(), deletions)
    else
      # Handle the case where this change does not include content
      case Map.get(change, "content") do
        nil ->
          {revision, []}

        map ->
          # First calculate the difference, if any, between the current revision and the
          # change that we are about to commit
          content1 = Map.get(revision.content, "model")
          content2 = Map.get(map, "model")

          {additions, deletions} = diff_activity_references(content1, content2)

          delete_activity_references(project_slug, revision, additions, deletions)
      end
    end
  end

  # If there are activity-reference changes, resolve those activity ids to
  # revisions and set their deleted flag appropriately
  defp delete_activity_references(project_slug, revision, additions, deletions) do
    case MapSet.union(additions, deletions) |> MapSet.to_list() do
      [] ->
        {revision, []}

      activity_ids ->
        activity_revisions =
          AuthoringResolver.from_resource_id(project_slug, activity_ids)
          |> Enum.map(fn revision ->
            {:ok, updated} =
              Oli.Resources.update_revision(revision, %{
                deleted: MapSet.member?(deletions, revision.resource_id)
              })

            updated
          end)

        {revision, activity_revisions}
    end
  end

  # Reverse references found in a resource update for activites. They will
  # come from the client as activity revision slugs, we store them internally
  # as activity ids.
  defp convert_to_activity_ids(%{"content" => %{"model" => content}} = update) do
    found_activities =
      Enum.filter(content, fn c -> Map.get(c, "type") == "activity-reference" end)
      |> Enum.map(fn c -> Map.get(c, "activitySlug") end)

    slug_to_id =
      case found_activities do
        [] ->
          %{}

        activity_slugs ->
          Oli.Resources.map_resource_ids_from_slugs(activity_slugs)
          |> Enum.reduce(%{}, fn e, m ->
            Map.put(m, Map.get(e, :slug), Map.get(e, :resource_id))
          end)
      end

    if Enum.all?(found_activities, fn slug -> Map.has_key?(slug_to_id, slug) end) do
      convert = fn c ->
        if Map.get(c, "type") == "activity-reference" do
          slug = Map.get(c, "activitySlug")
          Map.delete(c, "activitySlug") |> Map.put("activity_id", Map.get(slug_to_id, slug))
        else
          c
        end
      end

      {:ok, Map.put(update, "content", %{"model" => Enum.map(content, convert)})}
    else
      {:error, :not_found}
    end
  end

  # This version of this function handles the case where there is no content
  # present in the update
  defp convert_to_activity_ids(update) do
    {:ok, update}
  end

  # For the activity ids found in content, convert them to activity revision slugs
  defp convert_to_activity_slugs(%{"model" => content}, publication_id) do
    found_activities =
      Enum.filter(content, fn c -> Map.get(c, "type") == "activity-reference" end)
      |> Enum.map(fn c -> Map.get(c, "activity_id") end)

    id_to_slug =
      case found_activities do
        [] ->
          %{}

        activities ->
          Publishing.get_published_activity_revisions(publication_id, activities)
          |> Enum.reduce(%{}, fn e, m ->
            Map.put(m, Map.get(e, :resource_id), Map.get(e, :slug))
          end)
      end

    convert = fn c ->
      if Map.get(c, "type") == "activity-reference" do
        id = Map.get(c, "activity_id")
        Map.delete(c, "activity_id") |> Map.put("activitySlug", Map.get(id_to_slug, id))
      else
        c
      end
    end

    %{"model" => Enum.map(content, convert)}
  end

  # Take a list of maps containing the title, resource_id, and children (as a list of resource_ids)
  # and turn it into a list of maps of this form:
  #
  # %{
  #   id: the slug of the objective
  #   title: the title of the objective
  #   parentId: the id of the parent objective, nil if no parent objective
  # }
  #
  def construct_parent_references(revisions) do
    # create a map of ids to their parent ids
    parents =
      Enum.reduce(revisions, %{}, fn r, m ->
        Enum.reduce(r.children, m, fn c, n ->
          Map.put(n, c, r.resource_id)
        end)
      end)

    # now just transform the revision list to pair it down to including
    # id, title, and the new parent_id
    Enum.map(revisions, fn r ->
      %{
        id: r.resource_id,
        title: r.title,
        parentId: Map.get(parents, r.resource_id)
      }
    end)
  end

  # Create the resource editing context that we will supply to the client side editor
  defp create(
         publication_id,
         revision,
         project_slug,
         revision_slug,
         author,
         all_objectives,
         objectives,
         activities,
         editor_map
       ) do
    %Oli.Authoring.Editing.ResourceContext{
      authorEmail: author.email,
      projectSlug: project_slug,
      resourceSlug: revision_slug,
      editorMap: editor_map,
      objectives: objectives,
      allObjectives: all_objectives,
      title: revision.title,
      graded: revision.graded,
      content: convert_to_activity_slugs(revision.content, publication_id),
      activities: activities
    }
  end

  # Retrieve the latest (current) revision for a resource given the
  # active publication
  def get_latest_revision(publication, resource) do
    Publishing.get_published_revision(publication.id, resource.id)
  end

  # create a new revision only if the slug will change due to this update
  defp maybe_create_new_revision(
         {previous, changed_activity_revisions},
         publication,
         resource,
         author_id,
         update
       ) do
    title = Map.get(update, "title", previous.title)

    if title != previous.title do
      create_new_revision(
        {previous, changed_activity_revisions},
        publication,
        resource,
        author_id
      )
    else
      {previous, changed_activity_revisions}
    end
  end

  # Creates a new resource revision and updates the publication mapping
  def create_new_revision(
        {previous, changed_activity_revisions},
        publication,
        resource,
        author_id
      ) do
    attrs = %{author_id: author_id}
    {:ok, revision} = Resources.create_revision_from_previous(previous, attrs)

    mapping = Publishing.get_published_resource!(publication.id, resource.id)
    {:ok, _mapping} = Publishing.update_published_resource(mapping, %{revision_id: revision.id})

    {revision, changed_activity_revisions}
  end

  # Applies the update to the revision
  defp update_revision({revision, activity_revisions}, update, _) do
    {:ok, updated} = Oli.Resources.update_revision(revision, update)
    {updated, activity_revisions}
  end
end
