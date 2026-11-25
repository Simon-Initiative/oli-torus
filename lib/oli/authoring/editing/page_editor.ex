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
  alias Oli.Delivery.Page.ActivityContext
  alias Oli.Authoring.LearningObjectives.PageElement, as: LearningObjectivesPageElement
  alias Oli.Authoring.LearningObjectives.ProjectClassifier
  alias Oli.Rendering.Activity.ActivitySummary
  alias Oli.Activities
  alias Oli.Authoring.Editing.ActivityEditor
  alias Oli.Resources.ContentMigrator
  alias Oli.Features

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
end
