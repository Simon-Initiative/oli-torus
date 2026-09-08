defmodule Oli.Authoring.Editing.PageEditor do
  @moduledoc """
  This module provides content editing facilities for pages.

  """
  import Oli.Authoring.Editing.Utils
  import Ecto.Query, warn: false

  require Logger

  alias Oli.Authoring.{Locks, Course}
  alias Oli.Resources.{Collaboration, Revision, ResourceType}
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
  alias Oli.Authoring.LearningObjectives.PageElement, as: LearningObjectivesPageElement
  alias Oli.Authoring.LearningObjectives.ProjectClassifier
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Activities
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Resources.ContentMigrator
  alias Oli.Resources.ResourceType
  alias Oli.Features

  @page_id ResourceType.id_for_page()
  @alternatives_type_id ResourceType.id_for_alternatives()

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
          | {:error, {:feature_disabled, :alternatives | :experiments}}
          | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, author_email, update) do
    result =
      with {:ok, author} <- Accounts.get_author_by_email(author_email) |> trap_nil(),
           {:ok, project} <- Course.get_project_by_slug(project_slug) |> trap_nil(),
           {:ok} <- authorize_user(author, project),
           {:ok, publication} <-
             Publishing.project_working_publication(project_slug) |> trap_nil(),
           {:ok, resource} <- Resources.get_resource_from_slug(revision_slug) |> trap_nil(),
           {:ok, converted_update} <- convert_to_activity_ids(update),
           {:ok, normalized_update} <-
             normalize_learning_objectives_recommendations(project_slug, converted_update) do
        Repo.transaction(fn ->
          case Locks.update(project.slug, publication.id, resource.id, author.id) do
            # If we acquired or updated the lock, we can proceed
            lock_result when lock_result in [{:acquired}, {:updated}] ->
              latest_revision = get_latest_revision(publication, resource)

              case validate_feature_gated_content(latest_revision, converted_update, project) do
                :ok ->
                  latest_revision
                  |> resurrect_or_delete_activity_references(converted_update, project.slug)
                  |> maybe_create_new_revision(
                    publication,
                    project,
                    resource,
                    author.id,
                    normalized_update,
                    lock_result
                  )
                  |> update_revision(normalized_update, project.slug)
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
      {:ok, {revision, activity_revisions}} ->
        Enum.each(activity_revisions ++ [revision], fn r ->
          Broadcaster.broadcast_revision(r, project_slug)
        end)

        {:ok, revision}

      e ->
        e
    end
  end

  defp validate_feature_gated_content(
         %Revision{content: previous_content},
         update,
         project
       ) do
    case Map.fetch(update, "content") do
      :error ->
        :ok

      {:ok, updated_content} ->
        previous_alternatives = alternatives_by_identity(previous_content)
        updated_alternatives = alternatives_by_identity(updated_content)

        added_alternatives =
          Enum.reject(updated_alternatives, fn {identity, count} ->
            Map.get(previous_alternatives, identity, 0) >= count
          end)

        validate_added_alternatives(added_alternatives, project)
    end
  end

  defp validate_added_alternatives([], _project), do: :ok

  defp validate_added_alternatives(added_alternatives, project) do
    resource_ids = Enum.map(added_alternatives, &elem(&1, 0))

    case Enum.all?(resource_ids, &(is_integer(&1) and &1 > 0)) do
      true -> validate_added_alternatives_resources(added_alternatives, resource_ids, project)
      false -> {:error, {:not_found}}
    end
  end

  defp validate_added_alternatives_resources(added_alternatives, resource_ids, project) do
    strategies_by_resource_id =
      project.slug
      |> AuthoringResolver.from_resource_id(resource_ids)
      |> Enum.reduce(%{}, fn
        %Revision{
          resource_id: resource_id,
          resource_type_id: @alternatives_type_id,
          content: content
        },
        strategies
        when is_map(content) ->
          Map.put(
            strategies,
            resource_id,
            Map.get(content, "strategy", "user_section_preference")
          )

        _revision, strategies ->
          strategies
      end)

    Enum.reduce_while(added_alternatives, :ok, fn {resource_id, _count}, :ok ->
      case Map.fetch(strategies_by_resource_id, resource_id) do
        {:ok, strategy} ->
          case feature_enabled_for_strategy?(strategy, project) do
            true -> {:cont, :ok}
            false -> {:halt, {:error, feature_for_strategy(strategy)}}
          end

        :error ->
          {:halt, {:error, {:not_found}}}
      end
    end)
  end

  defp alternatives_by_identity(%{"model" => model}) when is_list(model) do
    Enum.reduce(model, %{}, &collect_alternatives/2)
  end

  defp alternatives_by_identity(_content), do: %{}

  defp collect_alternatives(%{"type" => "alternatives"} = content, counts) do
    identity = Map.get(content, "alternatives_id")
    counts = Map.update(counts, identity, 1, &(&1 + 1))

    collect_child_alternatives(content, counts)
  end

  defp collect_alternatives(content, counts) when is_map(content) do
    collect_child_alternatives(content, counts)
  end

  defp collect_alternatives(_content, counts), do: counts

  defp collect_child_alternatives(%{"children" => children}, counts) when is_list(children) do
    Enum.reduce(children, counts, &collect_alternatives/2)
  end

  defp collect_child_alternatives(_content, counts), do: counts

  defp feature_enabled_for_strategy?("upgrade_decision_point", project),
    do: project.experiments_enabled

  defp feature_enabled_for_strategy?("experiment_controlled", project),
    do: project.experiments_enabled

  defp feature_enabled_for_strategy?(_strategy, project), do: project.alternatives_enabled

  defp feature_for_strategy("upgrade_decision_point"), do: {:feature_disabled, :experiments}
  defp feature_for_strategy("experiment_controlled"), do: {:feature_disabled, :experiments}
  defp feature_for_strategy(_strategy), do: {:feature_disabled, :alternatives}

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
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         publication = Repo.preload(publication, :project),
         {:ok, %{deleted: false} = revision} <-
           AuthoringResolver.from_revision_slug(project_slug, revision_slug) |> trap_nil(),
         {:ok, %{content: content} = revision} <- maybe_migrate_revision_content(revision),
         {:ok, lo_well_formed} <-
           ProjectClassifier.ensure_classified(publication.project, publication),
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

      learning_objectives =
        learning_objectives_for_page(project_slug, revision, hierarchy, objectives)

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
         loWellFormed: lo_well_formed,
         learningObjectives: learning_objectives,
         allTags: Enum.map(tags, fn t -> %{id: t.resource_id, title: t.title} end),
         title: revision.title,
         graded: revision.graded,
         ai_enabled:
           case revision.ai_enabled do
             nil -> !revision.graded
             value -> value
           end,
         content: convert_to_activity_slugs(revision.content, publication.id),
         activities: activities,
         activityContexts:
           ActivityEditor.create_contexts(
             objectives_with_parent_reference,
             project_slug,
             activity_ids,
             lo_well_formed
           ),
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
         experimentsEnabled: publication.project.experiments_enabled,
         alternativesEnabled: publication.project.alternatives_enabled
       }}
    else
      _ -> {:error, :not_found}
    end
  end

  defp maybe_migrate_revision_content(%Revision{content: content} = revision) do
    {:ok, %Revision{revision | content: ContentMigrator.migrate(content, :page, to: :latest)}}
  end

  defp learning_objectives_for_page(project_slug, revision, hierarchy, objectives) do
    # The page element stores only advisory author configuration. Each authoring
    # page load refreshes membership from the current container hierarchy so new
    # or removed activity objective tags are reflected before the next normal save.
    if LearningObjectivesPageElement.has_learning_objectives_element?(revision.content) do
      resolve_learning_objectives_for_revision(project_slug, revision, hierarchy, objectives)
    else
      []
    end
  end

  @doc """
  Resolves the current container-scoped Learning Objectives for a page on demand.

  This supports the authoring insertion flow, where the page editor was loaded
  before a Learning Objectives element existed in the page content. The returned
  payload is the same snapshot used during normal page-editor load.
  """
  def resolve_learning_objectives(project_slug, revision_slug) do
    with {:ok, publication} <-
           Publishing.project_working_publication(project_slug) |> trap_nil(),
         {:ok, %{deleted: false} = revision} <-
           AuthoringResolver.from_revision_slug(project_slug, revision_slug) |> trap_nil(),
         {:ok, objectives} <-
           Publishing.get_published_objective_details(publication.id) |> trap_nil() do
      hierarchy = AuthoringResolver.full_hierarchy(project_slug)

      {:ok,
       resolve_learning_objectives_for_revision(project_slug, revision, hierarchy, objectives)}
    else
      _ -> {:error, :not_found}
    end
  end

  defp resolve_learning_objectives_for_revision(project_slug, revision, hierarchy, objectives) do
    LearningObjectivesPageElement.resolve(
      project_slug,
      revision.resource_id,
      hierarchy,
      objectives
    )
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

  defp normalize_learning_objectives_recommendations(
         project_slug,
         %{"content" => content} = update
       ) do
    {has_learning_objectives?, recommendation_ids} =
      learning_objectives_recommendation_ids(content)

    if has_learning_objectives? do
      valid_page_ids =
        case recommendation_ids do
          [] ->
            MapSet.new()

          _ ->
            project_slug
            |> valid_recommendation_page_ids(recommendation_ids)
            |> MapSet.new()
        end

      # Recommendation IDs come from advisory element state, but they are still
      # persisted page JSON. Filter them server-side so crafted editor payloads
      # cannot stash out-of-project or non-page resource ids for later rendering.
      content =
        Oli.Resources.PageContent.map(content, fn
          %{"type" => "learning_objectives", "learning_objectives" => configs} = element
          when is_list(configs) ->
            Map.put(
              element,
              "learning_objectives",
              Enum.map(configs, &normalize_learning_objective_config(&1, valid_page_ids))
            )

          %{"type" => "learning_objectives"} = element ->
            Map.put(element, "learning_objectives", [])

          element ->
            element
        end)

      {:ok, Map.put(update, "content", content)}
    else
      {:ok, update}
    end
  end

  defp normalize_learning_objectives_recommendations(_project_slug, update), do: {:ok, update}

  defp learning_objectives_recommendation_ids(content) do
    {_, {has_learning_objectives?, ids}} =
      Oli.Resources.PageContent.map_reduce(
        content,
        {false, []},
        fn
          %{"type" => "learning_objectives"} = element, {_found?, ids}, _tr_context ->
            element_ids =
              element
              |> learning_objective_configs()
              |> Enum.flat_map(&learning_objective_recommendation_ids/1)

            {element, {true, element_ids ++ ids}}

          element, acc, _tr_context ->
            {element, acc}
        end
      )

    {has_learning_objectives?, ids |> Enum.filter(&is_integer/1) |> Enum.uniq()}
  end

  defp learning_objective_configs(%{"learning_objectives" => configs}) when is_list(configs),
    do: configs

  defp learning_objective_configs(_element), do: []

  defp learning_objective_recommendation_ids(config) when is_map(config) do
    recommendation_id_list(Map.get(config, "revisit_pages", [])) ++
      recommendation_id_list(Map.get(config, "practice_pages", []))
  end

  defp learning_objective_recommendation_ids(_config), do: []

  defp recommendation_id_list(ids) when is_list(ids), do: ids
  defp recommendation_id_list(_ids), do: []

  defp normalize_learning_objective_config(config, valid_page_ids) when is_map(config) do
    config
    |> Map.put(
      "revisit_pages",
      normalize_learning_objective_page_ids(Map.get(config, "revisit_pages", []), valid_page_ids)
    )
    |> Map.put(
      "practice_pages",
      normalize_learning_objective_page_ids(Map.get(config, "practice_pages", []), valid_page_ids)
    )
  end

  defp normalize_learning_objective_config(config, _valid_page_ids), do: config

  defp normalize_learning_objective_page_ids(ids, valid_page_ids) when is_list(ids) do
    ids
    |> Enum.filter(fn id -> is_integer(id) and MapSet.member?(valid_page_ids, id) end)
    |> Enum.uniq()
  end

  defp normalize_learning_objective_page_ids(_ids, _valid_page_ids), do: []

  defp valid_recommendation_page_ids(project_slug, resource_ids) do
    Repo.all(
      from mapping in Oli.Publishing.PublishedResource,
        join: rev in Revision,
        on:
          rev.id == mapping.revision_id and
            rev.resource_id == mapping.resource_id,
        where:
          mapping.publication_id in subquery(
            AuthoringResolver.project_working_publication(project_slug)
          ) and
            mapping.resource_id in ^resource_ids and
            rev.resource_type_id == @page_id and
            rev.deleted == false and
            rev.resource_scope == :project,
        select: mapping.resource_id
    )
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
  #   parentIds: a list of parent objective ids, nil if no parent objectives
  # }
  #
  # Note: This function returns a unique entry per objective, with parentIds as a list
  # to support sub-objectives that have multiple parents.
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

    # Transform the revision list to include id, title, and parentIds (as a list or nil)
    Enum.map(revisions, fn revision ->
      parent_ids = Map.get(parents, revision.resource_id)

      %{
        id: revision.resource_id,
        title: revision.title,
        parentIds: parent_ids
      }
    end)
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
    # Extract activity references from content if present
    update_with_activity_refs =
      case Map.get(update, "content") do
        nil ->
          update

        content ->
          activity_ids =
            Oli.Authoring.Editing.Utils.activity_references(content)
            |> MapSet.to_list()

          Map.put(update, "activity_refs", activity_ids)
      end

    {:ok, updated} = Oli.Resources.update_revision(revision, update_with_activity_refs)
    {updated, activity_revisions}
  end
end
