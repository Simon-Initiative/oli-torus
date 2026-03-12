defmodule Oli.Authoring.Editing.ActivityEditor do
  @moduledoc """
  This module provides content editing facilities for activities.

  """

  import Oli.Authoring.Editing.Utils
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Resources
  alias Oli.Resources.Revision
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
  alias Oli.Activities.ActivityRegistration
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Authoring.Broadcaster
  alias Oli.Resources.ContentMigrator
  alias Oli.Adaptive.DynamicLinks.Telemetry, as: DynamicLinksTelemetry

  @adaptive_ai_trigger_part_type "janus-ai-trigger"
  @adaptive_ai_triggerable_part_types MapSet.new(["janus-image", "janus-navigation-button"])

  # Filters out objective ids that are no longer present in the list of all objectives
  @doc """
  Filters an objectives map so that only objective ids present in `all_objectives`
  remain for each part. Non-map inputs are passed through unchanged or defaulted
  to an empty map, keeping this function safe for varied shapes seen in legacy data.
  """
  def filter_objectives_to_existing(objectives, all_objectives) when is_map(objectives) do
    valid_ids =
      all_objectives
      |> Enum.map(& &1.id)
      |> MapSet.new()

    objectives
    |> Enum.reduce(%{}, fn {part_id, obj_ids}, acc ->
      filtered_ids =
        obj_ids
        |> List.wrap()
        |> Enum.filter(fn id -> MapSet.member?(valid_ids, id) end)

      Map.put(acc, part_id, filtered_ids)
    end)
  end

  def filter_objectives_to_existing(objectives, _all_objectives) when is_list(objectives) do
    objectives
  end

  def filter_objectives_to_existing(_objectives, _all_objectives), do: %{}

  @doc """
  Retrieves a list of activity resources.

  Returns:

  .`{:ok, [%Revision{}]}` when the revision is retrieved
  .`{:error, {:not_found}}` if the project is not found
  """
  @spec retrieve_bulk(String.t(), any(), any()) ::
          {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve_bulk(project_slug, activity_ids, author) when is_list(activity_ids) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
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
  @spec retrieve(String.t(), any(), any()) ::
          {:ok, %Revision{}} | {:error, {:not_found}}
  def retrieve(project_slug, activity_id, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project) do
      case AuthoringResolver.from_resource_id(project_slug, activity_id) do
        nil -> {:error, {:not_found}}
        revision -> {:ok, revision}
      end
    else
      error -> error
    end
  end

  @doc """
  Deletes an activity document or a secondary activity resource.

  Returns:

  .`{:ok, revision}` when the resource is deleted
  .`{:error, {:lock_not_acquired, {user_email, updated_at}}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project or activity or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this project or activity
  .`{:error, {:error}}` unknown error
  """
  @spec delete(String.t(), any(), any(), String.t()) ::
          {:ok, list()}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, any()}}
          | {:error, {:not_authorized}}
          | {:error, {:not_applicable}}
  def delete(project_slug, lock_id, activity_id, author) do
    secondary_id = Oli.Resources.ResourceType.id_for_secondary()
    activity_resource_id = Oli.Resources.ResourceType.id_for_activity()

    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, activity} <- Resources.get_resource(activity_id) |> trap_nil(),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource(lock_id) |> trap_nil(),
         {:ok, revision} <- get_latest_revision(publication.id, activity.id) |> trap_nil() do
      if secondary_id == revision.resource_type_id or
           activity_resource_id == revision.resource_type_id do
        Repo.transaction(fn ->
          update = %{"deleted" => true}

          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired the lock, we must first create a new revision
            {:acquired} ->
              create_new_revision(revision, publication, activity, author.id)
              |> update_revision(update, project.slug)

            # A successful lock update means we can safely edit the existing revision
            # unless, that is, if the update would change the corresponding slug.
            # In that case we need to create a new revision. Otherwise, future attempts
            # to resolve this activity via the historical slugs would fail.
            {:updated} ->
              update_revision(revision, update, project.slug)

            # error or not able to lock results in a failed edit
            result ->
              Repo.rollback(result)
          end
        end)
      else
        {:error, {:not_applicable}}
      end
    else
      error -> error
    end
  end

  def delete_bulk(project_slug, activity_ids, author) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil() do
      Repo.transaction(fn ->
        case process_deletes(project, publication, author, activity_ids) do
          {:ok, revisions} ->
            {:ok, revisions}

          {:error, e} ->
            Repo.rollback(e)
        end
      end)
    else
      error -> error
    end
  end

  defp process_deletes(_, _, _, []), do: {:ok, []}

  defp process_deletes(project, publication, author, [activity_id | rest]) do
    with {:ok, revision} <- process_or_error(project, publication, author, activity_id),
         {:ok, processed_rest} <- process_deletes(project, publication, author, rest),
         do: {:ok, [revision | processed_rest]}
  end

  defp process_or_error(project, publication, author, activity_id) do
    secondary_id = Oli.Resources.ResourceType.id_for_secondary()
    activity_resource_id = Oli.Resources.ResourceType.id_for_activity()

    with {:ok, activity} <- Resources.get_resource(activity_id) |> trap_nil(),
         {:ok, revision} <- get_latest_revision(publication.id, activity.id) |> trap_nil() do
      if secondary_id == revision.resource_type_id or
           activity_resource_id == revision.resource_type_id do
        update = %{"deleted" => true}

        case Locks.acquire(project.slug, publication.id, revision.resource_id, author.id) do
          # If we acquired the lock, we must first create a new revision
          {:acquired} ->
            updated =
              create_new_revision(revision, publication, activity, author.id)
              |> update_revision(update, project.slug)

            {:ok, updated}

          # error or not able to lock results in a failed edit
          result ->
            {:error, result}
        end
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
  @spec create_secondary(String.t(), String.t(), %Author{}, map()) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
          | {:error, {:invalid_update_field}}
  def create_secondary(project_slug, activity_id, author, update) do
    Repo.transaction(fn ->
      with {:ok, validated_update} <- validate_creation_request(update),
           {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project),
           {:ok, _} <-
             AuthoringResolver.from_resource_id(project_slug, activity_id) |> trap_nil(),
           {:ok, publication} <-
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, secondary_revision} <-
             create_secondary_revision(activity_id, author.id, validated_update),
           {:ok, _} <-
             Course.create_project_resource(%{
               project_id: project.id,
               resource_id: secondary_revision.resource_id
             })
             |> trap_nil(),
           {:ok, _mapping} <-
             Publishing.create_published_resource(%{
               publication_id: publication.id,
               resource_id: secondary_revision.resource_id,
               revision_id: secondary_revision.id
             }) do
        secondary_revision
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  defp create_secondary_revision(primary_id, author_id, attrs) do
    {:ok, resource} = Resources.create_new_resource()

    with_type =
      Map.put(attrs, "resource_type_id", Oli.Resources.ResourceType.id_for_secondary())
      |> Map.put("resource_id", resource.id)
      |> Map.put("author_id", author_id)
      |> Map.put("primary_resource_id", primary_id)

    Resources.create_revision(with_type)
  end

  defp authorize_edit(project_slug, author_email, updates) do
    with {:ok, _} <- validate_request(updates),
         {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
         {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil() do
      {:ok, {author, project, publication}}
    else
      error -> error
    end
  end

  @doc """
  Attempts to process a collection of edits for an activity specified by a given
  project and revision slug and activity slug for the author specified by email.

  The updates parameter is a list of maps containing key-value pairs of the
  attributes of a Revision that are to be edited, including the resource id. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%Revision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, [%Revision{}]}` when the edit processes successfully
  .`{:error, {:lock_not_acquired, {user_email, updated_at}}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, activity, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this activity
  .`{:error, {:invalid_update_field}}` if the update contains an invalid field
  .`{:error, {:error}}` unknown error
  """
  @spec bulk_edit(String.t(), String.t(), String.t(), %{}) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, any()}}
          | {:error, {:not_authorized}}
  def bulk_edit(project_slug, lock_id, author_email, updates) do
    result =
      with {:ok, {author, project, publication}} <-
             authorize_edit(project_slug, author_email, updates),
           {:ok, resource} <- Resources.get_resource(lock_id) |> trap_nil() do
        Repo.transaction(fn ->
          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired the lock, we must first create a new revision
            {:acquired} ->
              case process_with_new_revision(updates, publication, author, project) do
                {:ok, revisions} -> revisions
                {:error, e} -> Repo.rollback(e)
              end

            # A successful lock update means we can safely edit the existing revision
            # unless, that is, if the update would change the corresponding slug.
            # In that case we need to create a new revision. Otherwise, future attempts
            # to resolve this activity via the historical slugs would fail.
            {:updated} ->
              case process_with_maybe_new_revision(updates, publication, author, project) do
                {:ok, revisions} -> revisions
                {:error, e} -> Repo.rollback(e)
              end

            # error or not able to lock results in a failed edit
            result ->
              Repo.rollback(result)
          end
        end)
      else
        error -> error
      end

    case result do
      {:ok, revisions} ->
        Enum.each(revisions, fn r -> Broadcaster.broadcast_revision(r, project_slug) end)
        {:ok, revisions}

      e ->
        e
    end
  end

  defp process_with_new_revision(updates, publication, author, project) do
    with {:ok, update_resource_map} <- fetch_update_resource_map(updates) do
      project_page_targets = project_page_targets(project.id)

      Enum.reduce_while(updates, {:ok, []}, fn update, {:ok, revisions} ->
        case get_update_resource(update_resource_map, update) do
          nil ->
            {:halt, {:error, {:not_found}}}

          activity ->
            revision =
              get_latest_revision(publication.id, activity.id)
              |> create_new_revision(publication, activity, author.id)

            case update_revision(revision, update, project.id, project_page_targets) do
              {:ok, updated} -> {:cont, {:ok, [updated | revisions]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
        end
      end)
      |> case do
        {:ok, revisions} -> {:ok, Enum.reverse(revisions)}
        error -> error
      end
    end
  end

  defp process_with_maybe_new_revision(updates, publication, author, project) do
    with {:ok, update_resource_map} <- fetch_update_resource_map(updates) do
      project_page_targets = project_page_targets(project.id)

      Enum.reduce_while(updates, {:ok, []}, fn update, {:ok, revisions} ->
        case get_update_resource(update_resource_map, update) do
          nil ->
            {:halt, {:error, {:not_found}}}

          activity ->
            revision =
              get_latest_revision(publication.id, activity.id)
              |> maybe_create_new_revision(publication, project, activity, author.id, update)

            case update_revision(revision, update, project.id, project_page_targets) do
              {:ok, updated} -> {:cont, {:ok, [updated | revisions]}}
              {:error, reason} -> {:halt, {:error, reason}}
            end
        end
      end)
      |> case do
        {:ok, revisions} -> {:ok, Enum.reverse(revisions)}
        error -> error
      end
    end
  end

  defp fetch_update_resource_map(updates) when is_list(updates) do
    with {:ok, resource_ids} <- extract_update_resource_ids(updates) do
      resources =
        from(r in Oli.Resources.Resource,
          where: r.id in ^resource_ids
        )
        |> Repo.all()

      resource_map = Map.new(resources, fn resource -> {resource.id, resource} end)

      if map_size(resource_map) == length(resource_ids) do
        {:ok, resource_map}
      else
        {:error, {:not_found}}
      end
    end
  end

  defp extract_update_resource_ids(updates) do
    updates
    |> Enum.reduce_while({:ok, MapSet.new()}, fn update, {:ok, ids} ->
      case normalize_update_resource_id(Map.get(update, "resource_id")) do
        {:ok, resource_id} -> {:cont, {:ok, MapSet.put(ids, resource_id)}}
        :error -> {:halt, {:error, {:not_found}}}
      end
    end)
    |> case do
      {:ok, ids} -> {:ok, MapSet.to_list(ids)}
      error -> error
    end
  end

  defp get_update_resource(update_resource_map, update) do
    case normalize_update_resource_id(Map.get(update, "resource_id")) do
      {:ok, resource_id} -> Map.get(update_resource_map, resource_id)
      :error -> nil
    end
  end

  defp normalize_update_resource_id(resource_id) when is_integer(resource_id),
    do: {:ok, resource_id}

  defp normalize_update_resource_id(resource_id) when is_binary(resource_id) do
    case Integer.parse(resource_id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> :error
    end
  end

  defp normalize_update_resource_id(_), do: :error

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
  .`{:error, {:lock_not_acquired, {user_email, updated_at}}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, activity, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this activity
  .`{:error, {:invalid_update_field}}` if the update contains an invalid field
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t(), String.t(), any(), String.t(), %{}) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, any()}}
          | {:error, {:not_authorized}}
  def edit(project_slug, lock_id, activity_id, author_email, update) do
    result =
      with {:ok, {author, project, _publication}} <-
             authorize_edit(project_slug, author_email, update),
           {:ok, activity} <- Resources.get_resource(activity_id) |> trap_nil(),
           {:ok, publication} <-
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, resource} <- Resources.get_resource(lock_id) |> trap_nil() do
        project_page_targets = project_page_targets(project.id)

        Repo.transaction(fn ->
          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired the lock, we must first create a new revision
            {:acquired} ->
              updated =
                get_latest_revision(publication.id, activity.id)
                |> create_new_revision(publication, activity, author.id)
                |> update_revision(update, project.id, project_page_targets)

              case updated do
                {:ok, revision} ->
                  revision
                  |> possibly_release_lock(project, publication, resource, author, update)

                {:error, reason} ->
                  Repo.rollback(reason)
              end

            # A successful lock update means we can safely edit the existing revision
            # unless, that is, if the update would change the corresponding slug.
            # In that case we need to create a new revision. Otherwise, future attempts
            # to resolve this activity via the historical slugs would fail.
            {:updated} ->
              updated =
                get_latest_revision(publication.id, activity.id)
                |> maybe_create_new_revision(publication, project, activity, author.id, update)
                |> update_revision(update, project.id, project_page_targets)

              case updated do
                {:ok, revision} ->
                  revision
                  |> possibly_release_lock(project, publication, resource, author, update)

                {:error, reason} ->
                  Repo.rollback(reason)
              end

            # error or not able to lock results in a failed edit
            result ->
              Repo.rollback(result)
          end
        end)
      else
        error -> error
      end

    case result do
      {:ok, revision} ->
        Broadcaster.broadcast_revision(revision, project_slug)
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

  # if objectives to attach are provided, attach them to all parts
  defp attach_objectives(model, objectives_to_attach, objective_map) when objective_map == %{},
    do: attach_objectives_to_all_parts(model, objectives_to_attach)

  # if the objectives map is already built and can be used directly
  defp attach_objectives(_model, _objectives = [], objective_map), do: {:ok, objective_map}

  # takes the model of the activity to be created and a list of objective ids and
  # creates a map of all part ids to objective resource ids
  defp attach_objectives_to_all_parts(model, objectives) do
    result =
      case Oli.Activities.Model.parse(model) do
        {:ok, %{parts: parts}} ->
          %{
            "objectives" =>
              Enum.reduce(parts, %{}, fn %{id: id}, m -> Map.put(m, id, objectives) end)
          }
          |> Map.get("objectives")

        {:error, _e} ->
          %{}
      end

    {:ok, result}
  end

  # Creates a new activity revision and updates the publication mapping
  defp create_new_revision(previous, publication, activity, author_id) do
    {:ok, revision} =
      Resources.create_revision(%{
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
        activity_type_id: previous.activity_type_id,
        scope: previous.scope,
        tags: previous.tags
      })

    Publishing.get_published_resource!(publication.id, activity.id)
    |> Publishing.update_published_resource(%{revision_id: revision.id})

    revision
  end

  # create a new revision only if the slug will change due to this update
  defp maybe_create_new_revision(previous, publication, project, activity, author_id, update) do
    title = Map.get(update, "title", previous.title)

    needs_new_revision = Oli.Publishing.needs_new_revision_for_edit?(project.slug, previous.id)

    if title != previous.title or needs_new_revision do
      create_new_revision(previous, publication, activity, author_id)
    else
      previous
    end
  end

  # Applies the update to the revision, converting any objective slugs back to ids
  defp update_revision(revision, update, project_id, project_page_targets \\ nil) do
    objectives =
      if Map.has_key?(update, "objectives"),
        do: Map.get(update, "objectives"),
        else: revision.objectives

    # recombine authoring as a key underneath content, handling the four cases of
    # which combination of "authoring" and "content" keys are present in the update
    update =
      case {Map.get(update, "content"), Map.get(update, "authoring")} do
        # Neither key is present, so leave the update as-is
        {nil, nil} ->
          update

        # Only the "content" key is present, so we have to fetch the current "content/authoring" key
        # ensure that it set under this new "content"
        {content, nil} ->
          content =
            case Map.get(revision.content, "authoring") do
              nil -> content
              authoring -> Map.put(content, "authoring", authoring)
            end

          Map.put(update, "content", content)

        # Only the "authoring" key is present, so we must fetch the current "content" and insert this
        # authoring key under it
        {nil, authoring} ->
          Map.put(update, "content", Map.put(revision.content, "authoring", authoring))

        # Both authoring and content are present, just place authoring under this content
        {content, authoring} ->
          Map.put(update, "content", Map.put(content, "authoring", authoring))
      end

    parts =
      get_in(update, ["content", "authoring", "parts"]) ||
        get_in(revision.content, ["authoring", "parts"])

    with :ok <-
           validate_adaptive_dynamic_links(revision, update, project_id, project_page_targets),
         :ok <- validate_adaptive_trigger_content(revision, update, project_id) do
      update =
        normalize_adaptive_dynamic_links(revision, update, project_id, project_page_targets)

      update =
        objectives
        |> sync_objectives_to_parts(update, parts)
        |> maybe_update_scoring_strategy()

      # do not allow resource_id, if present, to be editable.  resource_id is only allowed to be
      # present in bulk update situations so that the server knows which resource we are editing
      update = Map.delete(update, "resource_id")

      case Resources.update_revision(revision, update) do
        {:ok, updated} ->
          maybe_emit_authoring_dynamic_link_telemetry(revision, updated, project_id)
          {:ok, updated}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp maybe_update_scoring_strategy(update) do
    case {update["content"]["customScoring"], get_scoring_strategy_from_content(update)} do
      {false, _} ->
        Map.put(
          update,
          "scoring_strategy_id",
          Oli.Resources.ScoringStrategy.get_id_by_type("total")
        )

      {_, scoring_strategy} ->
        Map.put(
          update,
          "scoring_strategy_id",
          Oli.Resources.ScoringStrategy.get_id_by_type(scoring_strategy)
        )
    end
  end

  defp get_scoring_strategy_from_content(%{"content" => %{"scoringStrategy" => scoring_strategy}})
       when scoring_strategy in ["best", "average"],
       do: scoring_strategy

  defp get_scoring_strategy_from_content(_), do: "total"

  # Check to see if this update is valid
  defp validate_request(update) when is_list(update) do
    all_valid? =
      Enum.map(update, fn u -> validate_request(u) end)
      |> Enum.all?(fn result ->
        case result do
          {:ok, _} -> true
          _ -> false
        end
      end)

    case all_valid? do
      true -> {:ok, update}
      _ -> {:error, {:invalid_update_field}}
    end
  end

  defp validate_request(update) do
    # Ensure that only these top-level keys are present
    allowed = MapSet.new(~w"objectives title content authoring releaseLock resource_id tags")

    case Map.keys(update)
         |> Enum.all?(fn k -> MapSet.member?(allowed, k) end) do
      false -> {:error, {:invalid_update_field}}
      true -> {:ok, update}
    end
  end

  defp validate_adaptive_dynamic_links(
         %Revision{} = revision,
         update,
         project_id,
         project_page_targets
       ) do
    if adaptive_activity?(revision) do
      authoring = authoring_from_update(update)
      validate_authoring_dynamic_links(authoring, project_id, project_page_targets)
    else
      :ok
    end
  end

  defp adaptive_activity?(%Revision{activity_type_id: nil}), do: false

  defp adaptive_activity?(%Revision{activity_type_id: activity_type_id}) do
    case Activities.get_registration(activity_type_id) do
      %ActivityRegistration{slug: "oli_adaptive"} -> true
      _ -> false
    end
  end

  defp authoring_from_update(%{"authoring" => authoring}) when is_map(authoring), do: authoring

  defp authoring_from_update(%{"content" => %{"authoring" => authoring}})
       when is_map(authoring),
       do: authoring

  defp authoring_from_update(_), do: nil

  defp validate_adaptive_trigger_content(%Revision{} = revision, update, project_id) do
    if adaptive_activity?(revision) and not project_allows_triggers?(project_id) do
      content = Map.get(update, "content", revision.content)

      case invalid_adaptive_trigger_content?(content) do
        true -> {:error, {:invalid_update_field}}
        false -> :ok
      end
    else
      :ok
    end
  end

  defp project_allows_triggers?(project_id) do
    from(p in Course.Project, where: p.id == ^project_id, select: p.allow_triggers)
    |> Repo.one()
    |> Kernel.==(true)
  end

  defp invalid_adaptive_trigger_content?(content) when is_map(content) do
    parts_layout = map_value(content, :partsLayout) || []
    authoring_parts = content |> map_value(:authoring) |> map_value(:parts) || []

    Enum.any?(parts_layout, &disallowed_adaptive_layout_part?/1) or
      Enum.any?(authoring_parts, &disallowed_adaptive_authoring_part?/1)
  end

  defp invalid_adaptive_trigger_content?(_), do: false

  defp disallowed_adaptive_authoring_part?(part) when is_map(part) do
    map_value(part, :type) == @adaptive_ai_trigger_part_type
  end

  defp disallowed_adaptive_authoring_part?(_), do: false

  defp disallowed_adaptive_layout_part?(part) when is_map(part) do
    type = map_value(part, :type)
    custom = map_value(part, :custom)

    type == @adaptive_ai_trigger_part_type or
      (MapSet.member?(@adaptive_ai_triggerable_part_types, type) and
         ai_trigger_configured?(custom))
  end

  defp disallowed_adaptive_layout_part?(_), do: false

  defp ai_trigger_configured?(custom) when is_map(custom) do
    map_value(custom, :enableAiTrigger) == true or
      present_text?(map_value(custom, :aiTriggerPrompt))
  end

  defp ai_trigger_configured?(_), do: false

  defp present_text?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_text?(_), do: false

  defp map_value(nil, _key), do: nil

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp validate_authoring_dynamic_links(nil, _project_id, _project_page_targets), do: :ok

  defp validate_authoring_dynamic_links(authoring, project_id, project_page_targets)
       when is_map(authoring) do
    {allowed_resource_ids, allowed_page_slugs, _slug_to_resource_id} =
      resolve_project_page_targets(project_id, project_page_targets)

    case Map.get(authoring, "parts", []) do
      parts when is_list(parts) ->
        Enum.reduce_while(parts, :ok, fn part, :ok ->
          case validate_part_dynamic_links(part, allowed_resource_ids, allowed_page_slugs) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      _ ->
        :ok
    end
  end

  defp validate_part_dynamic_links(
         %{"type" => "janus-text-flow"} = part,
         allowed_resource_ids,
         allowed_page_slugs
       ) do
    nodes = get_in(part, ["custom", "nodes"])

    case nodes do
      list when is_list(list) ->
        validate_nodes_dynamic_links(list, allowed_resource_ids, allowed_page_slugs)

      _ ->
        :ok
    end
  end

  defp validate_part_dynamic_links(_, _allowed_resource_ids, _allowed_page_slugs), do: :ok

  defp validate_nodes_dynamic_links(nodes, allowed_resource_ids, allowed_page_slugs)
       when is_list(nodes) do
    Enum.reduce_while(nodes, :ok, fn node, :ok ->
      with :ok <- validate_node_dynamic_link(node, allowed_resource_ids, allowed_page_slugs),
           :ok <-
             validate_nodes_dynamic_links(
               Map.get(node, "children", []),
               allowed_resource_ids,
               allowed_page_slugs
             ) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_nodes_dynamic_links(_, _allowed_resource_ids, _allowed_page_slugs), do: :ok

  defp validate_node_dynamic_link(
         %{"tag" => "a"} = node,
         allowed_resource_ids,
         allowed_page_slugs
       ) do
    href = Map.get(node, "href")
    idref = Map.get(node, "idref") || Map.get(node, "resource_id")

    case {internal_course_link?(href), idref} do
      {true, nil} ->
        with {:ok, slug} <- internal_slug(href),
             true <- MapSet.member?(allowed_page_slugs, slug) do
          :ok
        else
          _ -> {:error, {:invalid_update_field}}
        end

      {_, nil} ->
        :ok

      {_, ref} ->
        with {:ok, resource_id} <- normalize_resource_id(ref),
             true <- MapSet.member?(allowed_resource_ids, resource_id) do
          :ok
        else
          _ -> {:error, {:invalid_update_field}}
        end
    end
  end

  defp validate_node_dynamic_link(_, _allowed_resource_ids, _allowed_page_slugs), do: :ok

  defp internal_course_link?(href) when is_binary(href),
    do: String.starts_with?(href, "/course/link/")

  defp internal_course_link?(_), do: false

  defp normalize_resource_id(resource_id) when is_integer(resource_id), do: {:ok, resource_id}

  defp normalize_resource_id(resource_id) when is_binary(resource_id) do
    case Integer.parse(resource_id) do
      {parsed, ""} -> {:ok, parsed}
      _ -> {:error, :invalid_resource_id}
    end
  end

  defp normalize_resource_id(_), do: {:error, :invalid_resource_id}

  defp internal_slug(href) when is_binary(href) do
    case String.split(href, "/course/link/", parts: 2) do
      [_, slug_and_suffix] ->
        case String.split(slug_and_suffix, ["?", "#"], parts: 2) do
          [slug | _] when slug != "" -> {:ok, slug}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp internal_slug(_), do: :error

  defp validate_creation_request(update) do
    # Ensure that content, title and objectives are present.  Provide defaults if not.
    update = Map.put(update, "content", Map.get(update, "content", %{}))
    update = Map.put(update, "title", Map.get(update, "title", "default"))
    update = Map.put(update, "objectives", Map.get(update, "objectives", %{}))

    validate_request(update)
  end

  defp normalize_adaptive_dynamic_links(
         %Revision{} = revision,
         update,
         project_id,
         project_page_targets
       ) do
    if adaptive_activity?(revision) do
      case authoring_from_update(update) do
        nil ->
          update

        authoring when is_map(authoring) ->
          {_, _, page_slug_to_resource_id} =
            resolve_project_page_targets(project_id, project_page_targets)

          normalized_authoring =
            normalize_authoring_dynamic_links(authoring, page_slug_to_resource_id)

          case {Map.get(update, "content"), Map.get(update, "authoring")} do
            {%{} = content, _} ->
              Map.put(update, "content", Map.put(content, "authoring", normalized_authoring))

            {_, %{} = _authoring} ->
              Map.put(update, "authoring", normalized_authoring)

            _ ->
              update
          end
      end
    else
      update
    end
  end

  defp normalize_authoring_dynamic_links(authoring, page_slug_to_resource_id) do
    parts =
      case Map.get(authoring, "parts", []) do
        list when is_list(list) ->
          Enum.map(list, &normalize_part_dynamic_links(&1, page_slug_to_resource_id))

        other ->
          other
      end

    Map.put(authoring, "parts", parts)
  end

  defp normalize_part_dynamic_links(
         %{"type" => "janus-text-flow"} = part,
         page_slug_to_resource_id
       ) do
    case Map.get(part, "custom") do
      %{} = custom ->
        case Map.get(custom, "nodes") do
          list when is_list(list) ->
            normalized_nodes =
              Enum.map(list, &normalize_node_dynamic_links(&1, page_slug_to_resource_id))

            Map.put(part, "custom", Map.put(custom, "nodes", normalized_nodes))

          _ ->
            part
        end

      _ ->
        part
    end
  end

  defp normalize_part_dynamic_links(part, _page_slug_to_resource_id), do: part

  defp normalize_node_dynamic_links(node, page_slug_to_resource_id) when is_map(node) do
    node =
      case Map.get(node, "children") do
        children when is_list(children) ->
          Map.put(
            node,
            "children",
            Enum.map(children, &normalize_node_dynamic_links(&1, page_slug_to_resource_id))
          )

        _ ->
          node
      end

    case normalize_node_link_ref(node, page_slug_to_resource_id) do
      {:ok, ref} ->
        node
        |> Map.put("idref", ref)
        |> Map.put("resource_id", ref)
        |> Map.put("linkType", "page")

      :ignore ->
        node
    end
  end

  defp normalize_node_dynamic_links(node, _page_slug_to_resource_id), do: node

  defp normalize_node_link_ref(%{"tag" => "a"} = node, page_slug_to_resource_id) do
    href = Map.get(node, "href")
    idref = Map.get(node, "idref") || Map.get(node, "resource_id")

    cond do
      not is_nil(idref) ->
        normalize_resource_id(idref)

      internal_course_link?(href) ->
        with {:ok, slug} <- internal_slug(href),
             ref when is_integer(ref) <- Map.get(page_slug_to_resource_id, slug) do
          {:ok, ref}
        else
          _ -> :ignore
        end

      true ->
        :ignore
    end
  end

  defp normalize_node_link_ref(_, _page_slug_to_resource_id), do: :ignore

  defp resolve_project_page_targets(_project_id, {ids, slugs, slug_to_resource_id})
       when is_struct(ids, MapSet) and is_struct(slugs, MapSet) and is_map(slug_to_resource_id),
       do: {ids, slugs, slug_to_resource_id}

  defp resolve_project_page_targets(project_id, _), do: project_page_targets(project_id)

  defp project_page_targets(project_id) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    query =
      from p in Publication,
        join: pub_res in PublishedResource,
        on: pub_res.publication_id == p.id,
        join: rev in Revision,
        on: rev.id == pub_res.revision_id,
        where:
          p.project_id == ^project_id and is_nil(p.published) and
            rev.resource_type_id == ^page_id and rev.deleted == false,
        select: {rev.resource_id, rev.slug}

    entries = Repo.all(query)
    ids = entries |> Enum.map(fn {resource_id, _slug} -> resource_id end) |> MapSet.new()
    slugs = entries |> Enum.map(fn {_resource_id, slug} -> slug end) |> MapSet.new()

    slug_to_resource_id =
      entries |> Enum.map(fn {resource_id, slug} -> {slug, resource_id} end) |> Map.new()

    {ids, slugs, slug_to_resource_id}
  end

  defp maybe_emit_authoring_dynamic_link_telemetry(
         %Revision{} = previous,
         %Revision{} = updated,
         project_id
       ) do
    if adaptive_activity?(previous) do
      previous_links = authoring_dynamic_link_refs(previous)
      updated_links = authoring_dynamic_link_refs(updated)

      previous_paths = Map.keys(previous_links) |> MapSet.new()
      updated_paths = Map.keys(updated_links) |> MapSet.new()
      common_paths = MapSet.intersection(previous_paths, updated_paths)

      updated_count =
        Enum.count(common_paths, fn path ->
          Map.get(previous_links, path) != Map.get(updated_links, path)
        end)

      created_by_path = MapSet.size(MapSet.difference(updated_paths, previous_paths))
      removed_by_path = MapSet.size(MapSet.difference(previous_paths, updated_paths))

      replacement_updates =
        if updated_count == 0 do
          min(created_by_path, removed_by_path)
        else
          0
        end

      updated_count = updated_count + replacement_updates
      created_count = max(created_by_path - replacement_updates, 0)
      removed_count = max(removed_by_path - replacement_updates, 0)

      updated_count =
        if updated_count == 0 and map_size(previous_links) > 0 and map_size(updated_links) > 0 and
             previous_links != updated_links do
          1
        else
          updated_count
        end

      metadata = %{
        project_id: project_id,
        activity_resource_id: previous.resource_id,
        source: "activity_editor"
      }

      DynamicLinksTelemetry.authoring_created(created_count, metadata)
      DynamicLinksTelemetry.authoring_updated(updated_count, metadata)
      DynamicLinksTelemetry.authoring_removed(removed_count, metadata)
    end
  end

  defp maybe_emit_authoring_dynamic_link_telemetry(_, _, _), do: :ok

  defp authoring_dynamic_link_refs(%Revision{content: content}) do
    authoring =
      case content do
        %{} -> Map.get(content, "authoring", %{})
        _ -> %{}
      end

    authoring
    |> Map.get("parts", [])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {part, part_index}, acc ->
      accumulate_part_dynamic_link_refs(part, part_index, acc)
    end)
  end

  defp authoring_dynamic_link_refs(_), do: %{}

  defp accumulate_part_dynamic_link_refs(
         %{"type" => "janus-text-flow", "custom" => %{"nodes" => nodes}},
         part_index,
         acc
       )
       when is_list(nodes) do
    Enum.with_index(nodes)
    |> Enum.reduce(acc, fn {node, node_index}, links ->
      accumulate_node_dynamic_link_refs(node, "part:#{part_index}/node:#{node_index}", links)
    end)
  end

  defp accumulate_part_dynamic_link_refs(_, _part_index, acc), do: acc

  defp accumulate_node_dynamic_link_refs(node, path, acc) when is_map(node) do
    acc =
      case dynamic_link_reference(node) do
        nil -> acc
        reference -> Map.put(acc, path, reference)
      end

    node
    |> Map.get("children", [])
    |> List.wrap()
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {child, child_index}, links ->
      accumulate_node_dynamic_link_refs(child, "#{path}/child:#{child_index}", links)
    end)
  end

  defp accumulate_node_dynamic_link_refs(_, _path, acc), do: acc

  defp dynamic_link_reference(%{"tag" => "a"} = node) do
    case Map.get(node, "idref") || Map.get(node, "resource_id") do
      nil ->
        case internal_slug(Map.get(node, "href")) do
          {:ok, slug} -> "slug:#{slug}"
          _ -> nil
        end

      resource_id ->
        case normalize_resource_id(resource_id) do
          {:ok, normalized} -> "id:#{normalized}"
          _ -> nil
        end
    end
  end

  defp dynamic_link_reference(_), do: nil

  defp sync_objectives_to_parts(_objectives, update, nil), do: update

  defp sync_objectives_to_parts(objectives, update, parts) do
    objectives =
      objectives
      |> Enum.reduce(%{}, fn {part_id, list}, accumulator ->
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

  .`{:ok, {%Revision{}, transformed_content}}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create(String.t(), String.t(), %Author{}, %{}, []) ::
          {:ok, {%Revision{}, map()}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def create(
        project_slug,
        activity_type_slug,
        author,
        model,
        all_parts_objectives,
        scope \\ "embedded",
        title \\ nil,
        objective_map \\ %{},
        tags \\ []
      ) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, %{content: content} = activity} <-
           process_create_activity(
             project,
             author,
             publication,
             scope,
             activity_type_slug,
             all_parts_objectives,
             model,
             title,
             tags,
             objective_map
           ) do
      case Transformers.apply_transforms([activity]) do
        [{:ok, nil}] -> {:ok, {activity, content}}
        [{:ok, transformed}] -> {:ok, {activity, transformed}}
        _ -> {:ok, {activity, nil}}
      end
    else
      error ->
        error
    end
  end

  @doc """
  Attempts to process a request to create a list of new activities.

  Returns:

  .`{:ok, list({String.t(), %Revision{}})}` when the creation processes succeeds
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to create this activity
  .`{:error, {:error}}` unknown error
  """
  @spec create_bulk(String.t(), %Author{}, %{}) ::
          {:ok, list({String.t(), %Revision{}})}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:not_authorized}}
  def create_bulk(
        project_slug,
        author,
        bulk_activity_data,
        scope \\ "embedded"
      ) do
    with {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
         {:ok} <- authorize_user(author, project),
         {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil() do
      activities =
        Enum.reduce(bulk_activity_data, [], fn %{
                                                 "activityTypeSlug" => activity_type_slug,
                                                 "objectives" => objectives,
                                                 "content" => model,
                                                 "title" => title,
                                                 "tags" => tags
                                               },
                                               m ->
          case process_create_activity(
                 project,
                 author,
                 publication,
                 scope,
                 activity_type_slug,
                 objectives,
                 model,
                 title,
                 tags
               ) do
            {:ok, activity} ->
              m ++ [%{activity_type_slug: activity_type_slug, activity: activity}]

            _ ->
              m
          end
        end)

      {:ok, activities}
    else
      error -> error
    end
  end

  defp process_create_activity(
         project,
         author,
         publication,
         scope,
         activity_type_slug,
         objectives,
         model,
         title,
         tags,
         objective_map \\ %{}
       ) do
    Repo.transaction(fn ->
      with {:ok, activity_type} <-
             Activities.get_registration_by_slug(activity_type_slug) |> trap_nil(),
           {:ok, objectives} <- attach_objectives(model, objectives, objective_map),
           {:ok, activity} <-
             Resources.create_new(
               %{
                 title: title || activity_type.title,
                 scoring_strategy_id: Oli.Resources.ScoringStrategy.get_id_by_type("total"),
                 objectives: objectives,
                 author_id: author.id,
                 content: model,
                 scope: scope,
                 activity_type_id: activity_type.id,
                 tags: tags
               },
               Oli.Resources.ResourceType.id_for_activity()
             ),
           {:ok, _} <-
             Course.create_project_resource(%{
               project_id: project.id,
               resource_id: activity.resource_id
             })
             |> trap_nil(),
           {:ok, _mapping} <-
             Publishing.create_published_resource(%{
               publication_id: publication.id,
               resource_id: activity.resource_id,
               revision_id: activity.id
             }) do
        activity
      else
        error -> Repo.rollback(error)
      end
    end)
  end

  @spec create_context(any, any, any, any) ::
          {:error, :not_found}
          | {:ok,
             %Oli.Authoring.Editing.ActivityContext{
               activityId: any,
               activitySlug: binary,
               allObjectives: list,
               authorEmail: any,
               authoringElement: any,
               authoringScript: any,
               description: any,
               friendlyName: any,
               model: any,
               objectives: any,
               projectSlug: any,
               resourceId: any,
               resourceSlug: binary,
               resourceTitle: any,
               title: any
             }}
  @doc """
  Creates the context necessary to power a client side activity editor,
  where this activity is being editing within the context of being
  referenced from a resource.
  """
  def create_context(project_slug, revision_slug, activity_slug, author) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
         {:ok, all_objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, %{title: resource_title}} <-
           PageEditor.get_latest_revision(publication, resource) |> trap_nil(),
         {:ok, %{id: activity_id}} <-
           Resources.get_resource_from_slug(activity_slug) |> trap_nil(),
         {:ok,
          %{
            activity_type: activity_type,
            title: title,
            objectives: objectives,
            tags: tags
          } = revision} <-
           get_latest_revision(publication.id, activity_id) |> trap_nil(),
         {:ok, %{content: model}} <- maybe_migrate_revision_content(revision) do
      all_objectives_with_parents = PageEditor.construct_parent_references(all_objectives)
      filtered_objectives = filter_objectives_to_existing(objectives, all_objectives_with_parents)

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
        objectives: filtered_objectives,
        allObjectives: all_objectives_with_parents,
        typeSlug: activity_type.slug,
        tags: tags,
        variables:
          Oli.Delivery.Page.ActivityContext.build_variables_map(
            activity_type.variables,
            activity_type.petite_label
          )
      }

      {:ok, context}
    else
      _ -> {:error, :not_found}
    end
  end

  def create_contexts(all_objectives_with_parents, project_slug, activity_ids) do
    type_by_id =
      Activities.list_activity_registrations()
      |> Enum.reduce(%{}, fn t, m -> Map.put(m, t.id, t) end)

    AuthoringResolver.from_resource_id(project_slug, activity_ids)
    |> Enum.filter(fn r -> !is_nil(r) end)
    |> Enum.map(fn r ->
      activity_type = Map.get(type_by_id, r.activity_type_id)

      {:ok, r} = maybe_migrate_revision_content(r)

      filtered_objectives =
        filter_objectives_to_existing(r.objectives, all_objectives_with_parents)

      %ActivityContext{
        authoringScript: activity_type.authoring_script,
        authoringElement: activity_type.authoring_element,
        friendlyName: activity_type.title,
        description: activity_type.description,
        activityId: r.resource_id,
        activitySlug: r.slug,
        title: r.title,
        model: r.content,
        objectives: filtered_objectives,
        allObjectives: all_objectives_with_parents,
        typeSlug: activity_type.slug,
        tags: r.tags,
        variables:
          Oli.Delivery.Page.ActivityContext.build_variables_map(
            activity_type.variables,
            activity_type.petite_label
          )
      }
    end)
  end

  # Retrieve the latest (current) revision for a resource given the
  # active publication
  def get_latest_revision(publication_id, resource_id) do
    Publishing.get_published_revision(publication_id, resource_id)
    |> Repo.preload([:activity_type])
  end

  defp maybe_migrate_revision_content(%Revision{content: content} = revision) do
    {:ok, %Revision{revision | content: ContentMigrator.migrate(content, :activity, to: :latest)}}
  end
end
