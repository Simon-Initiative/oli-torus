defmodule Oli.Authoring.Audited.Activities do
  @moduledoc false

  # Activity editing commands of `Oli.Authoring.Audited`, which validates their arguments, and
  # the activity writes they and the removal commands run. Moved from `ActivityEditor`:
  # `edit/5`, `bulk_edit/4`, `delete/4`, and `delete_bulk/3`, with their private helpers
  # (revision creation and update, adaptive trigger and dynamic link validation and
  # normalization, objective sync, scoring strategy, learning model parameters, and LTI selection).
  # `ActivityEditor` keeps creation, reads, contexts, bundle repair, and `validate_request/1`.

  import Ecto.Query, warn: false
  import Oli.Authoring.Editing.Utils

  import Oli.Authoring.Audited.Support,
    only: [
      latest_revisions: 2,
      lock_working_mappings: 2,
      record_all: 2,
      record_resource_change: 5,
      resource_ids: 1
    ]

  require Logger

  alias Oli.Accounts
  alias Oli.Activities
  alias Oli.Activities.ActivityRegistration
  alias Oli.Adaptive.DynamicLinks.Telemetry, as: DynamicLinksTelemetry
  alias Oli.Auditing.{Changes, DotPolicy}
  alias Oli.Authoring.{Broadcaster, Course, Locks}
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.LearningModel.Parameters.Validation, as: ParameterValidation
  alias Oli.Publishing
  alias Oli.Publishing.PublishedResource
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.Revision

  @adaptive_ai_trigger_part_type "janus-ai-trigger"
  @adaptive_ai_triggerable_part_types MapSet.new(["janus-image", "janus-navigation-button"])

  ## Commands

  def edit_activity(context, project_slug, lock_id, activity_id, author_email, update) do
    project_slug
    |> editing(context, resource_ids([activity_id]), fn ->
      edit(project_slug, lock_id, activity_id, author_email, update)
    end)
    |> tap(fn
      {:ok, revision} -> Broadcaster.broadcast_revision(revision, project_slug)
      _error -> :ok
    end)
  end

  def edit_activities(context, project_slug, lock_id, author_email, updates) do
    resource_ids =
      case extract_update_resource_ids(updates) do
        {:ok, ids} -> ids
        _error -> []
      end

    project_slug
    |> editing(context, resource_ids, fn ->
      bulk_edit(project_slug, lock_id, author_email, updates)
    end)
    |> tap(fn
      {:ok, revisions} -> Enum.each(revisions, &Broadcaster.broadcast_revision(&1, project_slug))
      _error -> :ok
    end)
  end

  # Locks the working mappings of the edited activities, reads them, runs `write`, and records
  # what changed for each one.
  defp editing(project_slug, context, resource_ids, write) do
    case Course.get_project_by_slug(project_slug) do
      # The write reports a missing project with its usual error
      nil ->
        write.()

      project ->
        Repo.transaction(fn ->
          lock_working_mappings(project, resource_ids)
          before = latest_revisions(project, resource_ids)

          with {:ok, result} <- write.(),
               after_state = latest_revisions(project, resource_ids),
               :ok <-
                 record_all(resource_ids, fn id ->
                   record_activity(context, project, before[id], after_state[id])
                 end) do
            result
          else
            {:error, reason} -> Repo.rollback(reason)
            other -> Repo.rollback(other)
          end
        end)
    end
  end

  # Objectives and triggers each record their own event. Other content changes are ordinary
  # editing and record nothing; deletion goes through `delete/4` and the removal commands.
  defp record_activity(context, project, %Revision{} = before, %Revision{} = activity) do
    with :ok <-
           record_resource_change(
             context,
             project,
             activity,
             :learning_objectives_changed,
             Changes.diff(before, activity, %{objectives: :value})
           ) do
      record_resource_change(
        context,
        project,
        activity,
        :activation_settings_changed,
        DotPolicy.changes(
          DotPolicy.triggers(before.content),
          DotPolicy.triggers(activity.content)
        )
      )
    end
  end

  defp record_activity(_context, _project, _before, _after), do: :ok

  ## Writes

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
         {:ok, revision} <-
           ActivityEditor.get_latest_revision(publication.id, activity.id) |> trap_nil() do
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
         {:ok, revision} <-
           ActivityEditor.get_latest_revision(publication.id, activity.id) |> trap_nil() do
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

  defp authorize_edit(project_slug, author_email, updates) do
    with {:ok, _} <- ActivityEditor.validate_request(updates),
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

    result
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
              ActivityEditor.get_latest_revision(publication.id, activity.id)
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
              ActivityEditor.get_latest_revision(publication.id, activity.id)
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
  .`{:error, :stale_selection}` if a signed tool selection (the resource configuration
  chosen in the external tool) no longer matches the editor state
  .`{:error, {:error}}` unknown error

  A sole `deep_link_result` field supplies a server-signed selection token. It is
  validated under the existing editing lock and merged into current content;
  ordinary single/bulk content edits preserve the stored LTI selection.

  """
  @spec edit(
          String.t(),
          pos_integer() | String.t(),
          pos_integer() | String.t(),
          String.t(),
          map()
        ) ::
          {:ok, %Revision{}}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, any()}}
          | {:error, {:not_authorized}}
          | {:error, {:invalid_update_field}}
          | {:error, :stale_selection}
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
          lock_result = Locks.update(project.slug, publication.id, resource.id, author.id)
          selection_save? = Map.has_key?(update, "deep_link_result")

          update =
            case {lock_result, selection_save?} do
              {{status}, true} when status in [:acquired, :updated] ->
                with {:ok, request, selected} <-
                       Oli.Lti.AuthoringLaunch.validate_result(
                         author,
                         project.slug,
                         activity.id,
                         update["deep_link_result"]
                       ),
                     true <- request["lock_id"] == resource.id do
                  current = ActivityEditor.get_latest_revision(publication.id, activity.id)
                  %{"content" => Map.put(current.content, "deepLink", selected)}
                else
                  _ -> Repo.rollback(:stale_selection)
                end

              _ ->
                update
            end

          case lock_result do
            # If we acquired the lock, we must first create a new revision
            {:acquired} ->
              updated =
                ActivityEditor.get_latest_revision(publication.id, activity.id)
                |> create_new_revision(publication, activity, author.id)
                |> update_revision(update, project.id, project_page_targets, selection_save?)

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
                ActivityEditor.get_latest_revision(publication.id, activity.id)
                |> then(fn revision ->
                  case selection_save? do
                    true ->
                      create_new_revision(revision, publication, activity, author.id)

                    false ->
                      maybe_create_new_revision(
                        revision,
                        publication,
                        project,
                        activity,
                        author.id,
                        update
                      )
                  end
                end)
                |> update_revision(update, project.id, project_page_targets, selection_save?)

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

    result
  end

  defp possibly_release_lock(previous, project, publication, resource, author, update) do
    if Map.get(update, "releaseLock", false) do
      Locks.release(project.slug, publication.id, resource.id, author.id)
    end

    previous
  end

  # Creates a new activity revision and updates the publication mapping
  defp create_new_revision(previous, publication, activity, author_id) do
    {:ok, revision} =
      Resources.create_revision_from_previous(previous, %{author_id: author_id})

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

  # Applies revision edits and converts objective slugs back to IDs. Ordinary edits
  # retain the stored LTI selection (the external tool's chosen resource configuration);
  # only a validated signed-result save may replace it.
  defp update_revision(
         revision,
         update,
         project_id,
         project_page_targets \\ nil,
         selection_save? \\ false
       ) do
    revision = Repo.preload(revision, :activity_type)

    update =
      case selection_save? do
        true -> update
        false -> preserve_lti_selection(revision, update)
      end

    explicit_learning_model_parameters? =
      Map.has_key?(update, "learning_model_parameters") or
        Map.has_key?(update, :learning_model_parameters)

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
      maybe_authoring_parts(Map.get(update, "content")) ||
        maybe_authoring_parts(revision.content) || []

    with :ok <-
           validate_adaptive_dynamic_links(revision, update, project_id, project_page_targets),
         :ok <- validate_adaptive_trigger_content(revision, update, project_id) do
      update =
        normalize_adaptive_dynamic_links(revision, update, project_id, project_page_targets)

      update =
        objectives
        |> sync_objectives_to_parts(update, parts)
        |> maybe_update_scoring_strategy()

      update =
        reconcile_implicit_learning_model_parameters(
          revision,
          update,
          explicit_learning_model_parameters?
        )

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

  defp reconcile_implicit_learning_model_parameters(
         _revision,
         update,
         true
       ),
       do: update

  defp reconcile_implicit_learning_model_parameters(revision, update, false) do
    case Map.fetch(update, "content") do
      {:ok, content} ->
        Map.put(
          update,
          "learning_model_parameters",
          ParameterValidation.reconcile_inherited_parts(
            revision.learning_model_parameters,
            content
          )
        )

      :error ->
        update
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

  # Keeps ordinary autosaves from replacing or clearing the stored LTI selection
  # (the external tool's chosen resource configuration), even from an older client model.
  # Non-map LTI content is rejected rather than discarding the stored configuration.
  defp preserve_lti_selection(
         %Revision{activity_type: %{authoring_element: "lti-external-tool-authoring"}} = revision,
         %{"content" => content} = update
       ) do
    case is_map(content) do
      true ->
        content =
          case Map.fetch(revision.content, "deepLink") do
            {:ok, selection} -> Map.put(content, "deepLink", selection)
            :error -> Map.delete(content, "deepLink")
          end

        Map.put(update, "content", content)

      false ->
        Repo.rollback({:invalid_update_field})
    end
  end

  defp preserve_lti_selection(_, update), do: update

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

  # Reuses an already loaded registration when classifying the activity, avoiding
  # another lookup after revision update preparation has preloaded it.
  defp adaptive_activity?(%Revision{activity_type: %ActivityRegistration{slug: slug}}),
    do: slug == "oli_adaptive"

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
    parts_layout =
      content
      |> map_value(:partsLayout)
      |> normalize_list()

    authoring_parts =
      content
      |> map_value(:authoring)
      |> map_value(:parts)
      |> normalize_list()

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

  defp maybe_authoring_parts(content) when is_map(content) do
    case map_value(content, :authoring) do
      authoring when is_map(authoring) ->
        case map_value(authoring, :parts) do
          parts when is_list(parts) -> parts
          _ -> nil
        end

      _ ->
        case map_value(content, :content) do
          nested_content when is_map(nested_content) -> maybe_authoring_parts(nested_content)
          _ -> nil
        end
    end
  end

  defp maybe_authoring_parts(_), do: nil

  defp normalize_list(value) when is_list(value), do: value
  defp normalize_list(_), do: []

  defp present_text?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_text?(_), do: false

  defp map_value(nil, _key), do: nil

  defp map_value(map, key) when is_map(map) and is_atom(key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Atom.to_string(key))
    end
  end

  defp map_value(_, _key), do: nil

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

  defp validate_part_dynamic_links(
         %{"type" => "janus-capi-iframe"} = part,
         allowed_resource_ids,
         allowed_page_slugs
       ) do
    validate_iframe_dynamic_link(part, allowed_resource_ids, allowed_page_slugs)
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

  defp validate_iframe_dynamic_link(part, allowed_resource_ids, allowed_page_slugs) do
    src = Map.get(part, "src")
    idref = Map.get(part, "idref") || Map.get(part, "resource_id")
    source_type = Map.get(part, "sourceType")
    link_type = Map.get(part, "linkType")

    is_internal =
      internal_course_link?(src) or source_type == "page" or link_type == "page" or
        not is_nil(idref)

    if is_internal do
      case {internal_course_link?(src), idref} do
        {true, nil} ->
          with {:ok, slug} <- internal_slug(src),
               true <- MapSet.member?(allowed_page_slugs, slug) do
            :ok
          else
            _ -> {:error, {:invalid_update_field}}
          end

        {_, nil} ->
          {:error, {:invalid_update_field}}

        {_, ref} ->
          with {:ok, resource_id} <- normalize_resource_id(ref),
               true <- MapSet.member?(allowed_resource_ids, resource_id) do
            :ok
          else
            _ -> {:error, {:invalid_update_field}}
          end
      end
    else
      :ok
    end
  end

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

  defp normalize_part_dynamic_links(
         %{"type" => "janus-capi-iframe"} = part,
         page_slug_to_resource_id
       ) do
    case normalize_iframe_link_ref(part, page_slug_to_resource_id) do
      {:ok, ref} ->
        part
        |> Map.put("idref", ref)
        |> Map.put("resource_id", ref)
        |> Map.put("linkType", "page")
        |> Map.put("sourceType", "page")

      :ignore ->
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

  defp normalize_iframe_link_ref(part, page_slug_to_resource_id) when is_map(part) do
    src = Map.get(part, "src")
    idref = Map.get(part, "idref") || Map.get(part, "resource_id")

    cond do
      not is_nil(idref) ->
        normalize_resource_id(idref)

      internal_course_link?(src) ->
        with {:ok, slug} <- internal_slug(src),
             ref when is_integer(ref) <- Map.get(page_slug_to_resource_id, slug) do
          {:ok, ref}
        else
          _ -> :ignore
        end

      true ->
        :ignore
    end
  end

  defp normalize_iframe_link_ref(_, _page_slug_to_resource_id), do: :ignore

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
      previous_by_source = group_dynamic_link_refs_by_source(previous_links)
      updated_by_source = group_dynamic_link_refs_by_source(updated_links)

      all_sources =
        Map.keys(previous_by_source)
        |> Kernel.++(Map.keys(updated_by_source))
        |> MapSet.new()
        |> MapSet.to_list()

      Enum.each(all_sources, fn source ->
        previous_for_source = Map.get(previous_by_source, source, %{})
        updated_for_source = Map.get(updated_by_source, source, %{})

        {created_count, updated_count, removed_count} =
          dynamic_link_change_counts(previous_for_source, updated_for_source)

        metadata = %{
          project_id: project_id,
          activity_resource_id: previous.resource_id,
          source: source
        }

        DynamicLinksTelemetry.authoring_created(created_count, metadata)
        DynamicLinksTelemetry.authoring_updated(updated_count, metadata)
        DynamicLinksTelemetry.authoring_removed(removed_count, metadata)
      end)
    end
  end

  defp maybe_emit_authoring_dynamic_link_telemetry(_, _, _), do: :ok

  defp dynamic_link_change_counts(previous_links, updated_links) do
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

    {created_count, updated_count, removed_count}
  end

  defp group_dynamic_link_refs_by_source(refs) when is_map(refs) do
    Enum.reduce(refs, %{}, fn {path, %{reference: reference, source: source}}, acc ->
      source_refs = Map.get(acc, source, %{})
      Map.put(acc, source, Map.put(source_refs, path, reference))
    end)
  end

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

  defp accumulate_part_dynamic_link_refs(
         %{"type" => "janus-capi-iframe"} = part,
         part_index,
         acc
       ) do
    case iframe_dynamic_link_reference(part) do
      nil ->
        acc

      reference ->
        Map.put(acc, "part:#{part_index}", %{reference: reference, source: "iframe_authoring"})
    end
  end

  defp accumulate_part_dynamic_link_refs(_, _part_index, acc), do: acc

  defp accumulate_node_dynamic_link_refs(node, path, acc) when is_map(node) do
    acc =
      case dynamic_link_reference(node) do
        nil -> acc
        reference -> Map.put(acc, path, %{reference: reference, source: "activity_editor"})
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

  defp iframe_dynamic_link_reference(part) when is_map(part) do
    idref =
      Map.get(part, "idref") || Map.get(part, "resource_id") ||
        get_in(part, ["custom", "idref"]) || get_in(part, ["custom", "resource_id"])

    src = Map.get(part, "src") || get_in(part, ["custom", "src"])

    case idref do
      nil ->
        case internal_slug(src) do
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

  defp iframe_dynamic_link_reference(_), do: nil

  defp sync_objectives_to_parts(_objectives, update, nil), do: update

  defp sync_objectives_to_parts(objectives, update, parts) do
    objectives =
      objectives
      |> Enum.reduce(%{}, fn {part_id, list}, accumulator ->
        if Enum.any?(parts, &part_matches_objective_id?(&1, part_id)) do
          accumulator |> Map.put(part_id, list)
        else
          accumulator
        end
      end)

    Map.put(update, "objectives", objectives)
  end

  defp part_matches_objective_id?(%{"id" => id}, part_id),
    do: normalize_part_id(id) == normalize_part_id(part_id)

  defp part_matches_objective_id?(%{id: id}, part_id),
    do: normalize_part_id(id) == normalize_part_id(part_id)

  defp part_matches_objective_id?(id, part_id),
    do: normalize_part_id(id) == normalize_part_id(part_id)

  defp normalize_part_id(id) when is_binary(id), do: id
  defp normalize_part_id(id) when is_integer(id), do: Integer.to_string(id)
  defp normalize_part_id(id) when is_atom(id), do: Atom.to_string(id)
  defp normalize_part_id(_), do: nil
end
