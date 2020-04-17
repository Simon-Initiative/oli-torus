defmodule Oli.Editing.ActivityEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Editing.Utils
  alias Oli.Activities.ActivityRevision
  alias Oli.Editing.ResourceEditor
  alias Oli.Editing.ActivityContext
  alias Oli.Editing.SiblingActivity
  alias Oli.Resources
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Accounts.Author
  alias Oli.Course
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Locks

  @doc """
  Attempts to process an edit for a resource specified by a given
  project and revision slug, for the author specified by email.

  The update parameter is a map containing key-value pairs of the
  attributes of a ResourceRevision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%ResourceRevision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, %ResourceRevision{}}` when the edit processes successfully the
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t, String.t, String.t, String.t, %{})
    :: {:ok, %ActivityRevision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, activity_slug, author_email, update) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, activity} <- Activities.get_activity_from_slug(activity_slug) |> trap_nil(),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil()
    do
      Repo.transaction(fn ->

        case Locks.update(publication.id, resource.id, author.id) do

          # If we acquired the lock, we must first create a new revision
          {:acquired} -> get_latest_revision(publication.id, activity.id)
            |> create_new_revision(publication, activity, author.id)
            |> update_revision(update)

          # A successful lock update means we can safely edit the existing revision
          {:updated} -> get_latest_revision(publication, activity_slug)
            |> update_revision(update)

          # error or not able to lock results in a failed edit
          result -> Repo.rollback(result)
        end

      end)

    else
      error -> error
    end

  end


  # Creates a new resource revision and updates the publication mapping
  defp create_new_revision(previous, publication, activity, author_id) do

    {:ok, revision} = Activities.create_activity_revision(%{
      content: previous.content,
      objectives: previous.objectives,
      deleted: previous.deleted,
      slug: previous.slug,
      title: previous.title,
      author_id: author_id,
      activity_id: previous.activity_id,
      previous_revision_id: previous.id,
      activity_type_id: previous.activity_type_id
    })

    mapping = Publishing.get_activity_mapping(publication.id, activity.id)
    {:ok, _mapping} = Publishing.update_activity_mapping(mapping, %{ revision_id: revision.id })

    revision
  end

  # Applies the update to the revision, converting any objective slugs back to ids
  defp update_revision(revision, update) do
    {:ok, updated} = Activities.update_activity_revision(revision, update)
    updated
  end

  @doc """
  Attempts to process a request to create a new activity.

  Returns:

  .`{:ok, %ActivityRevision{}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create(String.t, String.t, %Author{}, %{})
    :: {:ok, %ActivityRevision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}}
  def create(project_slug, activity_type_slug, author, model) do

    Repo.transaction(fn ->

      with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, family} <- Activities.create_activity_family(),
         {:ok, activity} <- Activities.create_activity(%{project_id: project.id, family_id: family.id}),
         {:ok, activity_type} <- Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
         {:ok, revision} <- Activities.create_activity_revision(%{objectives: %{}, author_id: author.id, activity_id: activity.id, content: model, activity_type_id: activity_type.id}),
         {:ok, _mapping} <- Publishing.create_activity_mapping(%{publication_id: publication.id, activity_id: activity.id, revision_id: revision.id})
      do
        revision
      else
        error -> Repo.rollback(error)
      end

    end)

  end

  @doc """
  Creates the context necessary to power a client side activity editor,
  where this activity is being editing within the context of being
  referenced from a resource.
  """
  def create_context(project_slug, revision_slug, activity_slug, author) do

    with {:ok, publication} <- Publishing.get_unpublished_publication(project_slug, author.id) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slugs(project_slug, revision_slug) |> trap_nil(),
         {:ok, objectives} <- Publishing.get_published_objectives(publication.id) |> trap_nil(),
         {:ok, objectives_without_ids} <- ResourceEditor.strip_ids(objectives) |> trap_nil(),
         {:ok, %{content: content}} <- ResourceEditor.get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, %{activity_id: activity_id}} <- Activities.get_activity_revision(activity_slug) |> trap_nil(),
         {:ok, %{activity_type: activity_type, content: model, title: title}} <- get_latest_revision(publication.id, activity_id) |> trap_nil()
    do




      {previous, next} = find_sibling_activities(activity_id, content, publication.id)

      context = %ActivityContext{
        authoringScript: activity_type.authoring_script,
        authoringElement: activity_type.authoring_element,
        friendlyName: activity_type.title,
        description: activity_type.description,
        authorEmail: author.email,
        projectSlug: project_slug,
        resourceSlug: revision_slug,
        activitySlug: activity_slug,
        title: title,
        model: model,
        objectives: %{},
        allObjectives: objectives_without_ids,
        previousActivity: previous,
        nextActivity: next
      }

      {:ok, context}
    else
      _ -> {:error, :not_found}
    end
  end


  def get_latest_revision(publication_id, activity_id) do
    mapping = Publishing.get_activity_mapping(publication_id, activity_id)
    revision = Activities.get_activity_revision!(mapping.revision_id)

    Repo.preload(revision, :activity_type)
  end

  # Find the next and previous 'sibling' activities to the activity
  # specified by activity_id, in the array of content, all through
  # the lens of a specific publication. Previous and next refer to the
  # activities that precede or follow the given activity in the content
  # list, but only looking at activities.
  defp find_sibling_activities(activity_id, content, publication_id) do

    references = Enum.filter(content, fn c -> Map.get(c, "type") == "activity-reference" end)
    size = length(references)

    revisions = if (size == 1) do
      [nil, nil]
    else
      our_index = Enum.find_index(references, fn c -> Map.get(c, "activity_id") == activity_id end)

      map = Enum.zip(references, 0..(size - 1))
        |> Enum.reduce(%{}, fn {r, i}, m -> Map.put(m, i, Map.get(r, "activity_id")) end)

      # add one so that we can pattern match directly against size as a pin
      case (our_index + 1) do
        1 -> Publishing.get_published_activity_revisions(publication_id, [Map.get(map, 1)]) |> List.insert_at(0, nil)
        ^size -> Publishing.get_published_activity_revisions(publication_id, [Map.get(map, size - 2)]) |> List.insert_at(1, nil)
        other -> [
          Publishing.get_published_activity_revisions(publication_id, [Map.get(map, other - 2)]),
          Publishing.get_published_activity_revisions(publication_id, [Map.get(map, other)])
        ] |> List.flatten()
      end
    end

    # convert them to sibling activity representations
    as_siblings = Enum.map(revisions, fn r ->
      case r do
        nil -> nil
        rev -> %SiblingActivity{friendlyName: rev.activity_type.title, title: rev.title, activitySlug: rev.slug}
      end
    end)

    # return them as a tuple
    List.to_tuple(as_siblings)

  end


end
