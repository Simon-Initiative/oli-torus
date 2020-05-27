defmodule Oli.Authoring.Editing.ActivityEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Authoring.Editing.Utils
  alias Oli.Resources
  alias Oli.Resources.Revision
  alias Oli.Resources.Activity
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Authoring.Editing.ActivityContext
  alias Oli.Authoring.Editing.SiblingActivity
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Locks
  alias Oli.Activities.Transformers
  alias Oli.Publishing.AuthoringResolver

  @doc """
  Attempts to process an edit for an activity specified by a given
  project and revision slug and activity slug for the author specified by email.

  The update parameter is a map containing key-value pairs of the
  attributes of a Revision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%Revision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, %Revision{}}` when the edit processes successfully
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, activity, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this activity
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t, String.t, String.t, String.t, %{})
    :: {:ok, %Revision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, activity_slug, author_email, update) do

    with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, activity} <- Resources.get_resource_from_slug(activity_slug) |> trap_nil(),
         {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil()
    do
      Repo.transaction(fn ->

#        update = sync_objectives_to_parts(update)
        update = translate_objective_slugs_to_ids(update)

        case Locks.update(publication.id, resource.id, author.id) do

          # If we acquired the lock, we must first create a new revision
          {:acquired} -> get_latest_revision(publication.id, activity.id)
            |> create_new_revision(publication, activity, author.id)
            |> update_revision(update)

          # A successful lock update means we can safely edit the existing revision
          # unless, that is, if the update would change the corresponding slug.
          # In that case we need to create a new revision. Otherwise, future attempts
          # to resolve this activity via the historical slugs would fail.
          {:updated} -> get_latest_revision(publication.id, activity.id)
            |> maybe_create_new_revision(publication, activity, author.id, update)
            |> update_revision(update)

          # error or not able to lock results in a failed edit
          result -> Repo.rollback(result)
        end

      end)

    else
      error -> error
    end

  end

  defp translate_objective_slugs_to_ids(%{"objectives" => objectives} = update) do

    map = Map.values(objectives)
    |> Enum.reduce([], fn slugs, list -> list ++ slugs end)
    |> Oli.Resources.map_resource_ids_from_slugs()
    |> Enum.reduce(%{}, fn e, m -> Map.put(m, Map.get(e, :slug), Map.get(e, :resource_id)) end)

    objectives = Map.keys(objectives)
    |> Enum.reduce(%{}, fn key, m ->
      translated = Map.get(objectives, key) |> Enum.map(fn slug -> Map.get(map, slug) end)
      Map.put(m, key, translated)
    end)

    Map.put(update, "objectives", objectives)

  end

  defp translate_objective_slugs_to_ids(update), do: update

  defp translate_ids_to_slugs(project_slug, objectives) do

    all = Map.values(objectives)
    |> Enum.reduce([], fn ids, list -> list ++ ids end)

    map = AuthoringResolver.from_resource_id(project_slug, all)
    |> Enum.map(fn r -> r.slug end)
    |> Enum.zip(all)
    |> Enum.reduce(%{}, fn {slug, id}, m -> Map.put(m, id, slug) end)

    Map.keys(objectives)
    |> Enum.reduce(%{}, fn key, m ->
      translated = Map.get(objectives, key) |> Enum.map(fn id -> Map.get(map, id) end)
      Map.put(m, key, translated)
    end)

  end

  # Creates a new activity revision and updates the publication mapping
  defp create_new_revision(previous, publication, activity, author_id) do

    {:ok, revision} = Resources.create_revision(%{
      resource_type_id: previous.resource_type_id,
      content: previous.content,
      objectives: previous.objectives,
      deleted: previous.deleted,
      slug: previous.slug,
      title: previous.title,
      author_id: author_id,
      resource_id: previous.resource_id,
      previous_revision_id: previous.id,
      activity_type_id: previous.activity_type_id
    })

    Publishing.get_resource_mapping!(publication.id, activity.id)
    |> Publishing.update_resource_mapping(%{ revision_id: revision.id })

    revision
  end

  # create a new revision only if the slug will change due to this update
  defp maybe_create_new_revision(previous, publication, activity, author_id, update) do

    title = Map.get(update, "title", previous.title)

    if (title != previous.title) do
      create_new_revision(previous, publication, activity, author_id)
    else
      previous
    end
  end

  # Applies the update to the revision, converting any objective slugs back to ids
  defp update_revision(revision, update) do
    objectives = if Map.has_key?(update, "objectives"), do: Map.get(update, "objectives"), else: revision.objectives
    parts = update["content"]["authoring"]["parts"]
    update = sync_objectives_to_parts(objectives, update, parts)
    {:ok, updated} = Resources.update_revision(revision, update)
    updated
  end

  defp sync_objectives_to_parts(objectives, update, nil), do: update
  defp sync_objectives_to_parts(objectives, update, parts) do
    objectives = objectives |> Enum.reduce(%{}, fn({part_id, list}, accumulator) ->
      if Enum.any?(parts, fn x -> x["id"] == part_id end) do
        accumulator |> Map.put(part_id, list)
      else
        accumulator
      end
    end)
    Map.put(update, "objectives", objectives)
  end

  @doc """
  Attempts to process a request to create a new activity.

  Returns:

  .`{:ok, %Activity{}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create(String.t, String.t, %Author{}, %{})
    :: {:ok, %Revision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}}
  def create(project_slug, activity_type_slug, author, model) do

    Repo.transaction(fn ->

      with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, activity_type} <- Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
         {:ok, %{content: content} = activity} <- Activity.create_new(%{title: activity_type.title, scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("average"), objectives: %{}, author_id: author.id, content: model, activity_type_id: activity_type.id}),
         {:ok, _} <- Course.create_project_resource(%{ project_id: project.id, resource_id: activity.resource_id}) |> trap_nil(),
         {:ok, _mapping} <- Publishing.create_resource_mapping(%{publication_id: publication.id, resource_id: activity.resource_id, revision_id: activity.id})
      do
        case Transformers.apply_transforms(content) do
          {:ok, transformed} -> {activity, transformed}
          _ -> {activity, nil}
        end
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

    with {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
         {:ok, all_objectives} <- Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_without_ids} <- PageEditor.strip_ids(all_objectives) |> trap_nil(),
         {:ok, %{content: content}} <- PageEditor.get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, %{id: activity_id}} <- Resources.get_resource_from_slug(activity_slug) |> trap_nil(),
         {:ok, %{activity_type: activity_type, content: model, title: title, objectives: objectives}} <- get_latest_revision(publication.id, activity_id) |> trap_nil()
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
        objectives: translate_ids_to_slugs(project_slug, objectives),
        allObjectives: objectives_without_ids,
        previousActivity: previous,
        nextActivity: next
      }

      {:ok, context}
    else
      _ -> {:error, :not_found}
    end
  end

  # Retrieve the latest (current) revision for a resource given the
  # active publication
  def get_latest_revision(publication_id, resource_id) do
    Publishing.get_published_revision(publication_id, resource_id)
    |> Repo.preload([:activity_type])
  end

  # Find the next and previous 'sibling' activities to the activity
  # specified by activity_id, in the array of content, all through
  # the lens of a specific publication. Previous and next refer to the
  # activities that precede or follow the given activity in the content
  # list, but only looking at activities.
  #
  # Returns a tuple of SiblingActivity structs of the form { previous, next }
  # corresponding to the previous and next sibling activities. If there is
  # not a previous or next activity (e.g. the activity specified is first or is the
  # only activity) then nil is returned inside the tuple.
  defp find_sibling_activities(activity_id, %{"model" => content}, publication_id) do

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
