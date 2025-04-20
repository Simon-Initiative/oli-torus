defmodule Oli.Authoring.Editing.PageEditor do
  @moduledoc """
  This module provides content editing facilities for pages.

  """
  import Oli.Authoring.Editing.Utils
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Authoring.{Locks, Course}
  alias Oli.Resources.{Collaboration, Revision}
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
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Resources.ContentMigrator
  alias Oli.Features

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
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
           {:ok, converted_update} <- convert_to_activity_ids(update) do
        Repo.transaction(fn ->
          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired or updated the lock, we can proceed
            lock_result when lock_result in [{:acquired}, {:updated}] ->
              get_latest_revision(publication, resource)
              |> resurrect_or_delete_activity_references(converted_update, project.slug)
              |> maybe_create_new_revision(
                publication,
                project,
                resource,
                author.id,
                converted_update,
                lock_result
              )
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

        act_refs = determine_page_out_of(project_slug, revision)

        IO.inspect(
          act_refs,
          label: "activity references"
        )

        # IO.inspect(determine_page_out_of(project_slug, revision), label: "page out of")
        {:ok, revision}

      e ->
        e
    end
  end

  def determine_page_out_of(project_slug, %Revision{content: content}) do
    Oli.Resources.PageContent.flat_filter(
      content,
      &(&1["type"] == "activity-reference" || &1["type"] == "selection")
    )
    |> Enum.reduce(0, fn e, total_out_of ->
      case e["type"] do
        "activity-reference" ->
          activity =
            AuthoringResolver.from_resource_id(
              project_slug,
              e["activity_id"]
            )

          total_out_of + determine_activity_out_of(activity)

        "selection" ->
          case Oli.Activities.Realizer.Selection.parse(e) do
            {:ok, %Oli.Activities.Realizer.Selection{count: selection_count}} ->
              selection_count + total_out_of

            _ ->
              total_out_of
          end

        _ ->
          total_out_of
      end
    end)
    |> max(1.0)
  end

  defp determine_activity_out_of(%Revision{content: content}) do
    content["authoring"]["parts"]
    |> Enum.reduce(0, fn part, total_out_of ->
      total_out_of + determine_responses_max_score(part["responses"])
      # case part["outOf"] do
      #   nil ->
      #     total_out_of + determine_responses_max_score(part["responses"])

      #   out_of ->
      #     total_out_of + out_of
      # end
    end)
  end

  defp determine_responses_max_score(responses) do
    Enum.reduce(responses, 0, fn response, max_score ->
      case response["score"] do
        nil ->
          max_score

        score ->
          max(max_score, score)
      end
    end)
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
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil() do
      case Locks.acquire(project.slug, publication.id, resource.id, author.id) do
        # If we reacquired the lock, we must first create a new revision
        {:acquired} ->
          {:acquired}

        # error or not able to lock results in a failed edit
        {:lock_not_acquired, {locked_by, locked_at}} ->
          {:lock_not_acquired, {locked_by, locked_at}}

        error ->
          {:error, error}
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
           Publishing.project_working_publication(project_slug) |> trap_nil(),
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
           Publishing.project_working_publication(project_slug)
           |> Repo.preload(:project)
           |> trap_nil(),
         {:ok, %{deleted: false} = revision} <-
           AuthoringResolver.from_revision_slug(project_slug, revision_slug) |> trap_nil(),
         {:ok, %{content: content} = revision} <- maybe_migrate_revision_content(revision),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil(),
         {:ok, objectives_with_parent_reference} <-
           construct_parent_references(objectives) |> trap_nil(),
         {:ok, tags} <-
           Oli.Authoring.Editing.ResourceEditor.list(
             project_slug,
             author,
             Oli.Resources.ResourceType.id_for_tag()
           ),
         {:ok, activities} <- create_activities_map(project_slug, publication.id, content) do
      # Create the resource editing context that we will supply to the client side editor
      hierarchy = AuthoringResolver.full_hierarchy(project_slug)

      {:ok, {previous, next, _}, _} =
        Oli.Delivery.Hierarchy.build_navigation_link_map(hierarchy)
        |> Oli.Delivery.PreviousNextIndex.retrieve(revision.resource_id)

      activity_ids = activities_from_content(revision.content)

      {:ok, collab_space_config} =
        Collaboration.get_collab_space_config_for_page_in_project(revision_slug, project_slug)

      {:ok,
       %Oli.Authoring.Editing.ResourceContext{
         defaultEditor: Accounts.get_author_preference(author, :editor, "slate"),
         authorEmail: author.email,
         projectSlug: project_slug,
         resourceSlug: revision_slug,
         resourceId: revision.resource_id,
         editorMap: editor_map,
         objectives: revision.objectives,
         allObjectives: objectives_with_parent_reference,
         allTags: Enum.map(tags, fn t -> %{id: t.resource_id, title: t.title} end),
         title: revision.title,
         graded: revision.graded,
         content: convert_to_activity_slugs(revision.content, publication.id),
         activities: activities,
         activityContexts: ActivityEditor.create_contexts(project_slug, activity_ids),
         featureFlags:
           Features.list_features_and_states()
           |> Enum.reduce(%{}, fn {%Oli.Features.Feature{label: label}, value}, acc ->
             Map.put(acc, label, value)
           end),
         project: publication.project,
         previous_page: previous,
         next_page: next,
         collab_space_config: collab_space_config,
         optionalContentTypes: %{
           ecl: publication.project.allow_ecl_content_type,
           triggers: publication.project.allow_triggers
         },
         appsignalKey: Application.get_env(:appsignal, :client_key),
         hasExperiments: nil
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  defp maybe_migrate_revision_content(%Revision{content: content} = revision) do
    {:ok, %Revision{revision | content: ContentMigrator.migrate(content, :page, to: :latest)}}
  end

  def render_page_html(project_slug, content, author, options \\ []) do
    mode =
      if Keyword.get(options, :preview, false) do
        :author_preview
      else
        :delivery
      end

    graded = Keyword.get(options, :graded, false)

    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, attributes} <- Course.get_project_attributes(project_slug) |> trap_nil(),
         {:ok, activities} <- create_activity_summary_map(publication.id, content, graded),
         render_context <- %Rendering.Context{
           user: author,
           mode: mode,
           activity_map: activities,
           resource_summary_fn: &Resources.resource_summary(&1, project_slug, AuthoringResolver),
           alternatives_groups_fn: fn ->
             Resources.alternatives_groups(project_slug, AuthoringResolver)
           end,
           alternatives_selector_fn: &Resources.Alternatives.select/2,
           extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
           project_slug: project_slug,
           section_slug: project_slug,
           bib_app_params: Keyword.get(options, :bib_app_params, []),
           learning_language: attributes.learning_language
         } do
      Rendering.Page.render(render_context, content, Rendering.Page.Html)
    else
      _ -> {:error, :not_found}
    end
  end

  defp create_activity_summary_map(publication_id, content, graded) do
    # Now see if we even have any activities that need to be mapped
    found_activities =
      Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
        type == "activity-reference"
      end)
      |> Enum.map(fn %{"activity_id" => id} -> id end)

    # Assign ordinals into a map, keyed on resource (activity) id
    ordinal_map =
      Enum.with_index(found_activities, 1)
      |> Enum.reduce(%{}, fn {id, ordinal}, map ->
        if graded do
          Map.put(map, id, ordinal)
        else
          Map.put(map, id, nil)
        end
      end)

    # Get a mapping of the activities to their parent groups. We need to set this
    # correctly so that client-side pagination automation works
    group_mapping = Oli.Resources.PageContent.activity_parent_groups(content)

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
                        content: content
                      } = revision ->
         # To support 'test mode' in the editor, we give the editor an initial transformed
         # version of the model that it can immediately use for display purposes. If it fails
         # to transform, nil will be handled by the client and the raw model will be used
         # instead

         transformed =
           case Transformers.apply_transforms([revision]) do
             [{:ok, nil}] ->
               revision.content

             [{:ok, t}] ->
               t

             _ ->
               revision.content
           end

         # the activity type this revision pertains to
         type = Map.get(reg_map, activity_type_id)

         state =
           ActivityState.create_preview_state(
             transformed,
             Map.get(group_mapping, resource_id).group
           )

         %ActivitySummary{
           id: resource_id,
           attempt_guid: nil,
           model: ActivityContext.prepare_model(transformed, prune: false),
           state: ActivityContext.prepare_state(state),
           lifecycle_state: state.lifecycle_state,
           delivery_element: type.delivery_element,
           authoring_element: type.authoring_element,
           script: type.delivery_script,
           graded: graded,
           bib_refs: Map.get(content, "bibrefs", []),
           ordinal: Map.get(ordinal_map, resource_id),
           variables:
             Oli.Delivery.Page.ActivityContext.build_variables_map(
               type.variables,
               type.petite_label
             )
         }
       end)
       |> Enum.reduce(%{}, fn summary, acc -> Map.put(acc, summary.id, summary) end)}
    else
      {:ok, %{}}
    end
  end

  defp activities_from_content(content) do
    Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
      type == "activity-reference"
    end)
    |> Enum.map(fn %{"activity_id" => id} -> id end)
  end

  # From the array of maps found in a resource revision content, produce a
  # map of the content of the activity revisions that pertain to the
  # current publication
  defp create_activities_map(_, publication_id, content) do
    # Now see if we even have any activities that need to be mapped
    found_activities = activities_from_content(content)

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
                        resource_id: activity_id,
                        activity_type_id: activity_type_id,
                        objectives: objectives,
                        slug: slug,
                        content: content,
                        title: title
                      } ->
         %{
           type: "activity",
           typeSlug: Map.get(id_to_slug, activity_type_id),
           activitySlug: slug,
           resourceId: activity_id,
           # TODO: remove once all the deps are updated
           activity_id: activity_id,
           model: content,
           objectives: objectives,
           title: title
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
      deletions = activity_references(revision.content)
      delete_activity_references(project_slug, revision, MapSet.new(), deletions)
    else
      # Handle the case where this change does not include content
      case Map.get(change, "content") do
        nil ->
          {revision, []}

        content2 ->
          # First calculate the difference, if any, between the current revision and the
          # change that we are about to commit
          content1 = revision.content

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
        AuthoringResolver.from_resource_id(project_slug, activity_ids)
        |> Enum.filter(fn r -> !is_nil(r) end)
        |> Enum.each(fn revision ->
          Oli.Publishing.ChangeTracker.track_revision(project_slug, revision, %{
            deleted: MapSet.member?(deletions, revision.resource_id)
          })
        end)

        activity_revisions = AuthoringResolver.from_resource_id(project_slug, activity_ids)

        {revision, activity_revisions}
    end
  end

  # Reverse references found in a resource update for activities. They will
  # come from the client as activity revision slugs, we store them internally
  # as activity ids.
  defp convert_to_activity_ids(%{"content" => content} = update) do
    found_activities =
      Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
        type == "activity-reference"
      end)
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
      content =
        Oli.Resources.PageContent.map(content, fn c ->
          if Map.get(c, "type") == "activity-reference" do
            slug = Map.get(c, "activitySlug")
            Map.delete(c, "activitySlug") |> Map.put("activity_id", Map.get(slug_to_id, slug))
          else
            c
          end
        end)

      {:ok, Map.put(update, "content", content)}
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
  defp convert_to_activity_slugs(content, publication_id) do
    found_activities =
      Oli.Resources.PageContent.flat_filter(content, fn %{"type" => type} ->
        type == "activity-reference"
      end)
      |> Enum.map(fn %{"activity_id" => id} -> id end)

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

    Oli.Resources.PageContent.map(content, fn c ->
      if Map.get(c, "type") == "activity-reference" do
        id = Map.get(c, "activity_id")
        Map.delete(c, "activity_id") |> Map.put("activitySlug", Map.get(id_to_slug, id))
      else
        c
      end
    end)
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
  # Take into account that more than one entry with the same id could be present, as the sub
  # objectives can have more than one parent.
  #
  def construct_parent_references(revisions) do
    # create a map of ids to their parent ids
    parents =
      Enum.reduce(revisions, %{}, fn r, m ->
        Enum.reduce(r.children, m, fn c, n ->
          case Map.get(n, c) do
            nil -> Map.put(n, c, [r.resource_id])
            value -> Map.put(n, c, [r.resource_id | value])
          end
        end)
      end)

    # now just transform the revision list to pair it down to including
    # id, title, and the new parent_id
    Enum.reduce(revisions, [], fn revision, result ->
      case Map.get(parents, revision.resource_id) do
        nil ->
          concatenate_to_revision_parent_result(revision, nil, result)

        parents ->
          Enum.reduce(parents, result, fn parent_id, result ->
            concatenate_to_revision_parent_result(revision, parent_id, result)
          end)
      end
    end)
  end

  defp concatenate_to_revision_parent_result(revision, parent_id, result) do
    [
      %{
        id: revision.resource_id,
        title: revision.title,
        parentId: parent_id
      }
      | result
    ]
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
         project,
         resource,
         author_id,
         update,
         lock_result
       ) do
    title = Map.get(update, "title", previous.title)

    needs_new_revision = Oli.Publishing.needs_new_revision_for_edit?(project.slug, previous.id)

    if title != previous.title or needs_new_revision or lock_result == {:acquired} do
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
