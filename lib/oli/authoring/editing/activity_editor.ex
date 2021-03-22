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
  alias Oli.Publishing
  alias Oli.Activities
  alias Oli.Accounts.Author
  alias Oli.Authoring.Course
  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Authoring.Locks
  alias Oli.Activities.Transformers
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Authoring.Broadcaster

  import Ecto.Query, warn: false

  @doc """
  Retrieves a list of activity resources.

  Returns:

  .`{:ok, [%Revision{}]}` when the revision is retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec retrieve_bulk(String.t, any(), any())
    :: {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve_bulk(project_slug, activity_ids, author) when is_list(activity_ids) do

    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
      {:ok} <- authorize_user(author, project)
    do
      case AuthoringResolver.from_resource_id(project_slug, activity_ids) do
        nil -> {:error, {:not_found}}
        revisions -> {:ok, revisions}
      end
    else
      error -> error
    end

  end

  @doc """
  Retrieves an activity resource.

  Returns:

  .`{:ok, %Revision{}}` when the revision is retrieved
  .`{:error, {:not_found}}` if the project or resource is not found
  """
  @spec retrieve(String.t, any(), any())
    :: {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve(project_slug, activity_id, author) do

    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
      {:ok} <- authorize_user(author, project)
    do
      case AuthoringResolver.from_resource_id(project_slug, activity_id) do
        nil -> {:error, {:not_found}}
        revision -> {:ok, revision}
      end
    else
      error -> error
    end

  end

  @doc """
  Deletes a secondary activity resource.

  Returns:

  .`{:ok, revision}` when the resource is deleted
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project or activity or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project or activity
  .`{:error, {:error}}` unknown error
  """
  @spec delete(String.t, any(), any(), String.t)
    :: {:ok, list()} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def delete(project_slug, lock_id, activity_id, author) do

    secondary_id = Oli.Resources.ResourceType.get_id_by_type("secondary")

    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
      {:ok} <- authorize_user(author, project),
      {:ok, activity} <- Resources.get_resource(activity_id) |> trap_nil(),
      {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
      {:ok, resource} <- Resources.get_resource(lock_id) |> trap_nil(),
      {:ok, revision} <- get_latest_revision(publication.id, activity.id) |> trap_nil()
    do

      if secondary_id == revision.resource_type_id do

        Repo.transaction(fn ->

          update = %{"deleted" => true}

          case Locks.update(project.slug, publication.id, resource.id, author.id) do

            # If we acquired the lock, we must first create a new revision
            {:acquired} -> create_new_revision(revision, publication, activity, author.id)
              |> update_revision(update, project.slug)

            # A successful lock update means we can safely edit the existing revision
            # unless, that is, if the update would change the corresponding slug.
            # In that case we need to create a new revision. Otherwise, future attempts
            # to resolve this activity via the historical slugs would fail.
            {:updated} -> update_revision(revision, update, project.slug)

            # error or not able to lock results in a failed edit
            result -> Repo.rollback(result)
          end

        end)

      else
        {:error, {:not_applicable}}
      end

    else
      error -> error
    end

  end

  @doc """
  Creates a new secondary document for an activity.

  Returns:

  .`{:ok, %Activity{}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project
  .`{:error, {:invalid_update_field}}` if the update contains an invalid field
  .`{:error, {:error}}` unknown error
  """
  @spec create_secondary(String.t, String.t, %Author{}, map())
    :: {:ok, %Revision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}} | {:error, {:invalid_update_field}}
  def create_secondary(project_slug, activity_id, author, update) do

    Repo.transaction(fn ->

      with {:ok, validated_update} <- validate_creation_request(update),
        {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
        {:ok} <- authorize_user(author, project),
        {:ok, _} <- AuthoringResolver.from_resource_id(project_slug, activity_id) |> trap_nil(),
        {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
        {:ok, secondary_revision} <- create_secondary_revision(activity_id, author.id, validated_update),
        {:ok, _} <- Course.create_project_resource(%{ project_id: project.id, resource_id: secondary_revision.resource_id}) |> trap_nil(),
        {:ok, _mapping} <- Publishing.create_resource_mapping(%{publication_id: publication.id, resource_id: secondary_revision.resource_id, revision_id: secondary_revision.id})
      do
        secondary_revision
      else
        error -> Repo.rollback(error)
      end

    end)

  end

  defp create_secondary_revision(primary_id, author_id, attrs) do

    {:ok, resource} = Resources.create_new_resource()

    with_type = Map.put(attrs, "resource_type_id", Oli.Resources.ResourceType.get_id_by_type("secondary"))
      |> Map.put("resource_id", resource.id)
      |> Map.put("author_id", author_id)
      |> Map.put("primary_resource_id", primary_id)

    Resources.create_revision(with_type)

  end

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
  .`{:error, {:invalid_update_field}}` if the update contains an invalid field
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t, String.t, any(), String.t, %{})
    :: {:ok, %Revision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:lock_not_acquired}} | {:error, {:not_authorized}}
  def edit(project_slug, lock_id, activity_id, author_email, update) do

    result = with {:ok, _} <- validate_request(update),
         {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, activity} <- Resources.get_resource(activity_id) |> trap_nil(),
         {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource(lock_id) |> trap_nil()
    do
      Repo.transaction(fn ->

        case Locks.update(project.slug, publication.id, resource.id, author.id) do

          # If we acquired the lock, we must first create a new revision
          {:acquired} -> get_latest_revision(publication.id, activity.id)
            |> create_new_revision(publication, activity, author.id)
            |> update_revision(update, project.slug)
            |> possibly_release_lock(project, publication, resource, author, update)

          # A successful lock update means we can safely edit the existing revision
          # unless, that is, if the update would change the corresponding slug.
          # In that case we need to create a new revision. Otherwise, future attempts
          # to resolve this activity via the historical slugs would fail.
          {:updated} -> get_latest_revision(publication.id, activity.id)
            |> maybe_create_new_revision(publication, activity, author.id, update)
            |> update_revision(update, project.slug)
            |> possibly_release_lock(project, publication, resource, author, update)

          # error or not able to lock results in a failed edit
          result -> Repo.rollback(result)
        end

      end)

    else
      error -> error
    end

    case result do
      {:ok, revision} ->
        Broadcaster.broadcast_revision(revision, project_slug)
        {:ok, revision}
      e -> e
    end

  end

  defp possibly_release_lock(previous, project, publication, resource, author, update) do
    if Map.get(update, "releaseLock", false) do
      Locks.release(project.slug, publication.id, resource.id, author.id)
    end

    previous
  end

  # takes the model of the activity to be created and a list of objective ids and
  # creates a map of all part ids to objective resource ids
  defp attach_objectives_to_all_parts(model, objectives) do

    result = case Oli.Activities.Model.parse(model) do
      {:ok, %{parts: parts}} ->

        %{"objectives" => Enum.reduce(parts, %{}, fn %{id: id}, m -> Map.put(m, id, objectives) end)}
        |> Map.get("objectives")

      {:error, _e} ->
        %{}
    end

    {:ok, result}
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
      primary_resource_id: previous.primary_resource_id,
      scoring_strategy_id: previous.scoring_strategy_id,
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
  defp update_revision(revision, update, _) do

    objectives = if Map.has_key?(update, "objectives"), do: Map.get(update, "objectives"), else: revision.objectives

    # recombine authoring as a key underneath content, handling the four cases of
    # which combination of "authoring" and "content" keys are present in the update
    update = case {Map.get(update, "content"), Map.get(update, "authoring")} do

      # Neither key is present, so leave the update as-is
      {nil, nil} -> update

      # Only the "content" key is present, so we have to fetch the current "content/authoring" key
      # ensure that it set under this new "content"
      {content, nil} ->
        content = case Map.get(revision.content, "authoring") do
          nil -> content
          authoring -> Map.put(content, "authoring", authoring)
        end
        Map.put(update, "content", content)

      # Only the "authoring" key is present, so we must fetch the current "content" and insert this
      # authoring key under it
      {nil, authoring} ->
        Map.put(update, "content", Map.put(revision.content, "authoring", authoring))

      # Both authoring and content are present, just place authoring under this content
      {content, authoring} -> Map.put(update, "content", Map.put(content, "authoring", authoring))

    end

    parts = update["content"]["authoring"]["parts"]
    update = sync_objectives_to_parts(objectives, update, parts)

    {:ok, updated} = Resources.update_revision(revision, update)

    updated
  end

  # Check to see if this update is valid
  defp validate_request(update) do

    # Ensure that only these top-level keys are present
    allowed = MapSet.new(~w"objectives title content authoring releaseLock")

    case Map.keys(update)
    |> Enum.all?(fn k -> MapSet.member?(allowed, k) end) do

      false -> {:error, {:invalid_update_field}}
      true -> {:ok, update}
    end

  end

  defp validate_creation_request(update) do

    # Ensure that content, title and objectives are present.  Provide defaults if not.
    update = Map.put(update, "content", Map.get(update, "content", %{}))
    update = Map.put(update, "title", Map.get(update, "title", "default"))
    update = Map.put(update, "objectives", Map.get(update, "objectives", %{}))

    validate_request(update)

  end


  defp sync_objectives_to_parts(_objectives, update, nil), do: update
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
  @spec create(String.t, String.t, %Author{}, %{}, [])
    :: {:ok, %Revision{}} | {:error, {:not_found}} | {:error, {:error}} | {:error, {:not_authorized}}
  def create(project_slug, activity_type_slug, author, model, objectives) do

    Repo.transaction(fn ->

      with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <- Publishing.get_unpublished_publication_by_slug!(project_slug) |> trap_nil(),
         {:ok, activity_type} <- Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
         {:ok, attached_objectives} <- attach_objectives_to_all_parts(model, objectives),
         {:ok, %{content: content} = activity} <- Activity.create_new(%{title: activity_type.title, scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("total"), objectives: attached_objectives, author_id: author.id, content: model, activity_type_id: activity_type.id}),
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
         {:ok, %{title: resource_title}} <- PageEditor.get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, %{id: activity_id}} <- Resources.get_resource_from_slug(activity_slug) |> trap_nil(),
         {:ok, %{activity_type: activity_type, content: model, title: title, objectives: objectives}} <- get_latest_revision(publication.id, activity_id) |> trap_nil()
    do

      context = %ActivityContext{
        authoringScript: activity_type.authoring_script,
        authoringElement: activity_type.authoring_element,
        friendlyName: activity_type.title,
        description: activity_type.description,
        authorEmail: author.email,
        projectSlug: project_slug,
        resourceId: resource.id,
        resourceSlug: revision_slug,
        resourceTitle: resource_title,
        activityId: activity_id,
        activitySlug: activity_slug,
        title: title,
        model: model,
        objectives: objectives,
        allObjectives: PageEditor.construct_parent_references(all_objectives),
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

end
