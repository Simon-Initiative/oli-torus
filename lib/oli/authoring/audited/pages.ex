defmodule Oli.Authoring.Audited.Pages do
  @moduledoc false

  # Page editing commands of `Oli.Authoring.Audited`, which validates their arguments, and the
  # page writes they run. Moved from `PageEditor`: `edit/4` and its private helpers (activity
  # reference conversion, learning-objective recommendation normalization, the feature check of
  # added alternatives, the activity deleted-flag sync, and revision creation). `PageEditor`
  # keeps the lock, context, and rendering functions.

  import Ecto.Query, only: [from: 2]
  import Oli.Authoring.Audited.Support, only: [record_resource_change: 5]
  import Oli.Authoring.Editing.Utils

  alias Oli.Accounts
  alias Oli.Auditing.{Changes, DotPolicy}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.{Broadcaster, Course, Locks}
  alias Oli.Authoring.Audited.Content
  alias Oli.Authoring.Editing.PageEditor
  alias Oli.Publishing
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Repo
  alias Oli.Resources
  alias Oli.Resources.{PageContent, ResourceType, Revision}

  @page_id ResourceType.id_for_page()
  @alternatives_type_id ResourceType.id_for_alternatives()

  # Page settings recorded by authoring_settings_changed; objectives have their own event and
  # children and parent objectives do not belong to pages.
  @page_settings Map.drop(Fields.authoring_configuration(), [
                   :objectives,
                   :children,
                   :parent_objective_id,
                   :selection_rules
                 ])

  ## Commands

  def edit_page(context, project_slug, revision_slug, author_email, update) do
    Repo.transaction(fn ->
      with {:ok, result} <- edit(project_slug, revision_slug, author_email, update),
           :ok <- record_page(context, Course.get_project_by_slug(project_slug), result) do
        result
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, result} ->
        broadcast(result, project_slug)
        {:ok, result.revision}

      error ->
        error
    end
  end

  # A deleted page records its removal with the activities it took along. Otherwise each removed
  # activity reference records the activity's removal, and each kind of setting its own event.
  defp record_page(
         context,
         project,
         %{before: %Revision{deleted: false}, revision: %Revision{deleted: true}} = result
       ) do
    Content.record_removal(
      context,
      project,
      result.before,
      result.revision,
      removed_activities(result)
    )
  end

  defp record_page(context, project, %{before: before, revision: page} = result) do
    with :ok <- record_activity_removals(context, project, result),
         :ok <-
           record_resource_change(
             context,
             project,
             page,
             :authoring_settings_changed,
             Map.merge(
               Changes.diff(before, page, @page_settings),
               selection_changes(before, page)
             )
           ),
         :ok <-
           record_resource_change(
             context,
             project,
             page,
             :learning_objectives_changed,
             Changes.diff(before, page, %{objectives: :value})
           ),
         :ok <-
           record_resource_change(
             context,
             project,
             page,
             :dot_settings_changed,
             Changes.diff(before, page, %{ai_enabled: :value})
           ) do
      record_resource_change(
        context,
        project,
        page,
        :activation_settings_changed,
        DotPolicy.changes(DotPolicy.triggers(before.content), DotPolicy.triggers(page.content))
      )
    end
  end

  defp record_activity_removals(context, project, result) do
    before = Map.new(result.activities_before, &{&1.resource_id, &1})

    Enum.reduce_while(result.activities, :ok, fn activity, :ok ->
      case Content.record_removal(context, project, before[activity.resource_id], activity, []) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp removed_activities(result) do
    before = Map.new(result.activities_before, &{&1.resource_id, &1})

    result.activities
    |> Enum.filter(&(&1.deleted and match?(%Revision{deleted: false}, before[&1.resource_id])))
    |> Enum.map(& &1.resource_id)
  end

  # Bank selections, compared by ID: only the selections added, removed, or changed are recorded.
  defp selection_changes(before, page) do
    old = selections(before.content)
    new = selections(page.content)

    case Enum.reject(Enum.uniq(Map.keys(old) ++ Map.keys(new)), &(old[&1] == new[&1])) do
      [] ->
        %{}

      ids ->
        ids = Enum.sort_by(ids, &to_string/1)

        %{
          "selection_rules" => %{
            "operation" => "set",
            "before" => Enum.flat_map(ids, &List.wrap(old[&1])),
            "after" => Enum.flat_map(ids, &List.wrap(new[&1]))
          }
        }
    end
  end

  defp selections(%{"model" => _} = content) do
    content
    |> PageContent.flat_filter(&match?(%{"type" => "selection"}, &1))
    |> Map.new(fn selection ->
      {selection["id"],
       %{"id" => selection["id"], "count" => selection["count"], "logic" => selection["logic"]}}
    end)
  end

  defp selections(_content), do: %{}

  ## Writes

  @doc """
  Attempts to process an edit for a resource specified by a given
  project and revision slug, for the author specified by email.
  Moved from `PageEditor.edit/4`; returns the revision read under the lock as `:before`, and the
  activity revisions whose deleted flag changed, without broadcasting them (see `broadcast/2`).

  The update parameter is a map containing key-value pairs of the
  attributes of a resource Revision that are to be edited. It can
  contain any number of key-value pairs, but the keys must match
  the schema of `%Revision{}` struct.

  Not acquiring the lock here is considered a failure, as it is
  not an expected condition that a client would encounter. The client
  should have first acquired the lock via `acquire_lock`.

  Returns:

  .`{:ok, %{before: %Revision{}, revision: %Revision{}, activities_before: [...], activities: [...]}}`
  when the edit processes successfully
  .`{:error, {:lock_not_acquired}}` if the lock could not be acquired or updated
  .`{:error, {:not_found}}` if the project, resource, or user cannot be found
  .`{:error, {:not_authorized}}` if the user is not authorized to edit this resource
  .`{:error, {:error}}` unknown error
  """
  @spec edit(String.t(), String.t(), String.t(), %{}) ::
          {:ok, map()}
          | {:error, {:not_found}}
          | {:error, {:error}}
          | {:error, {:lock_not_acquired, {String.t(), Calendar.naive_datetime()}}}
          | {:error, {:feature_disabled, :alternatives | :experiments}}
          | {:error, {:not_authorized}}
  def edit(project_slug, revision_slug, author_email, update) do
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
            latest_revision = PageEditor.get_latest_revision(publication, resource)

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
                |> then(fn {revision, activities} ->
                  %{
                    before: latest_revision,
                    revision: revision,
                    activities_before: activities.before,
                    activities: activities.after
                  }
                end)

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
  end

  @doc "Broadcasts the revisions an `edit/4` result changed: the activities, then the page."
  def broadcast(%{revision: revision, activities: activities}, project_slug) do
    Enum.each(activities ++ [revision], &Broadcaster.broadcast_revision(&1, project_slug))
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
          {revision, %{before: [], after: []}}

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
        {revision, %{before: [], after: []}}

      activity_ids ->
        activities_before =
          AuthoringResolver.from_resource_id(project_slug, activity_ids)
          |> Enum.filter(fn r -> !is_nil(r) end)

        activities_before
        |> Enum.each(fn revision ->
          Publishing.ChangeTracker.track_revision(project_slug, revision, %{
            deleted: MapSet.member?(deletions, revision.resource_id)
          })
        end)

        activity_revisions = AuthoringResolver.from_resource_id(project_slug, activity_ids)

        {revision, %{before: activities_before, after: activity_revisions}}
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
