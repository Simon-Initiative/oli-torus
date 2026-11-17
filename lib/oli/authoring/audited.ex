defmodule Oli.Authoring.Audited do
  @moduledoc """
  Application boundary for audited authoring commands: project lifecycle, collaborators,
  project settings, and content and media removal.

  Each command writes its change and its events in one transaction. A project's owner is the
  author who creates, copies, or imports it, and is recorded as the affected author of the
  creation event; ownership never changes afterwards. Collaborator changes record
  `project_collaborator_changed` with the collaborator as the affected author and the `status`
  and `role` before and after.

  Project settings commands record `project_settings_changed` with the fields that changed, and
  record nothing when no field changed. Each settings form passes the fields it edits; any other
  key returns `{:error, :protected}`. The trigger switch records `activation_settings_changed`.

  Removing a page, container, activity, alternatives group, or bibliography entry records
  `authoring_content_removed` (`bank_question_deleted` for a banked activity) with the previous
  and resulting revisions; deleting media records `media_deleted` per item. Content that was
  already deleted records nothing.

  Commands do not authorize the actor; callers keep their existing authorization. Checks that
  lived in the migrated functions (the owner cannot be removed, only project authors upgrade
  the learning model) run inside the transaction.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, only: [from: 2]

  alias Ecto.Multi
  alias Oli.Accounts
  alias Oli.Accounts.{Author, AuthorToken}
  alias Oli.Auditing
  alias Oli.Auditing.{Changes, Context, LogEvent}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Authoring.Audited.{Content, Projects, Settings}
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.{Collaborators, Course, Editing}
  alias Oli.Authoring.Course.Project
  alias Oli.Authoring.Editing.{ActivityEditor, ContainerEditor}
  alias Oli.Authoring.MediaLibrary.MediaItem
  alias Oli.Publishing.{AuthoringResolver, PublishedResource}
  alias Oli.Publishing.Publications.Publication
  alias Oli.Repo
  alias Oli.Resources.Revision

  @collaborator_fields %{status: :value, role: :value}

  @type command_error ::
          :invalid_request | :not_found | :nested_transaction | :protected | term()

  ## Projects

  @doc """
  Creates a project titled `title` owned by `author`, with its root container and initial
  working publication, and records `project_created`.

  Options:

    * `:learning_model_version` - defaults to `:lkt_aoa`, the application default.
    * `:lo_well_formed` - sets the trusted learning-objective flag instead of the schema default.

  Only trusted setup (Scenarios) passes options.

  Returns the same map as before (`:project`, `:resource_revision`, `:publication`, ...).
  """
  @spec create_project(Context.t(), String.t(), %Author{}, map(), keyword()) ::
          {:ok, map()} | {:error, command_error()}
  def create_project(context, title, author, attrs \\ %{}, opts \\ [])

  def create_project(%Context{} = context, title, %Author{} = author, attrs, opts)
      when is_map(attrs) do
    learning_model_version = Keyword.get(opts, :learning_model_version, :lkt_aoa)
    lo_well_formed = Keyword.get(opts, :lo_well_formed, :use_default)

    create(context, :project_created, fn ->
      Projects.create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def create_project(_context, _title, _author, _attrs, _opts), do: {:error, :invalid_request}

  @doc """
  Creates the project of an imported course archive with its validated learning model and
  records `project_imported`. Runs inside the archive ingest transaction, so a failed import
  rolls the project and its event back.
  """
  @spec import_project(Context.t(), String.t(), %Author{}, :naive | :lkt_aoa, map()) ::
          {:ok, map()} | {:error, command_error()}
  def import_project(
        %Context{} = context,
        title,
        %Author{} = author,
        learning_model_version,
        attrs
      )
      when learning_model_version in [:naive, :lkt_aoa] and is_map(attrs) do
    lo_well_formed = Map.get(attrs, :lo_well_formed)
    attrs = Map.delete(attrs, :lo_well_formed)

    create(context, :project_imported, fn ->
      Projects.create(title, author, attrs, learning_model_version, lo_well_formed)
    end)
  end

  def import_project(_context, _title, _author, _learning_model_version, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Copies the project with `project_slug` for `author`, who becomes the owner of the copy, and
  records `project_duplicated` with the source project.

  Options: `:author_in_project_title` appends the author's email to the title instead of
  " Copy", as before.
  """
  @spec duplicate_project(Context.t(), String.t(), %Author{}, keyword()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def duplicate_project(context, project_slug, author, opts \\ [])

  def duplicate_project(%Context{} = context, project_slug, %Author{} = author, opts)
      when is_binary(project_slug) do
    Repo.transaction(fn ->
      with {:ok, {base_project, project}} <- Projects.duplicate(project_slug, author, opts),
           :ok <-
             record(context, project_event(:project_duplicated, project, author, base_project)) do
        project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def duplicate_project(_context, _project_slug, _author, _opts), do: {:error, :invalid_request}

  @doc """
  Marks the project with ID `project_id` deleted and records `project_deleted`. A project that
  is already deleted returns it unchanged, without an event.
  """
  @spec delete_project(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def delete_project(%Context{} = context, project_id) when is_integer(project_id) do
    Repo.transaction(fn ->
      with {:ok, project} <- Projects.lock_project(project_id),
           {:ok, deleted} <- delete_once(context, project) do
        deleted
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_project(_context, _project_id), do: {:error, :invalid_request}

  defp delete_once(_context, %Project{status: :deleted} = project), do: {:ok, project}

  defp delete_once(context, project) do
    with {:ok, deleted} <- Projects.mark_deleted(project),
         :ok <- record(context, project_event(:project_deleted, deleted, nil, nil)) do
      {:ok, deleted}
    end
  end

  # Function-style transactions (the creation steps use them) compose as savepoints of an
  # enclosing transaction, so the archive ingest can call `import_project/5` inside its own.
  defp create(context, event_type, build) do
    Repo.transaction(fn ->
      with {:ok, %{project: project, author_project: owner} = created} <- build.(),
           :ok <- record(context, project_event(event_type, project, owner, nil)) do
        created
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp project_event(event_type, %Project{} = project, owner, source) do
    key =
      case event_type do
        :project_created -> "created"
        :project_imported -> "imported"
        :project_duplicated -> "duplicated"
        :project_deleted -> "deleted"
      end

    %{
      event_type: event_type,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      event_key: "project:#{project.id}:#{key}",
      details: %{project_title: project.title}
    }
    |> put_owner(owner)
    |> put_source(source)
  end

  defp put_owner(proposal, nil), do: proposal
  defp put_owner(proposal, %Author{id: id}), do: Map.put(proposal, :affected, {:author, id})

  defp put_owner(proposal, %AuthorProject{author_id: id}),
    do: Map.put(proposal, :affected, {:author, id})

  defp put_source(proposal, nil), do: proposal

  defp put_source(proposal, %Project{} = source) do
    proposal
    |> Map.put(:refs, [%{role: :source, type: :project, id: source.id, label: source.title}])
    |> Map.update!(:details, &Map.put(&1, :source_project_id, source.id))
  end

  ## Project settings

  @doc """
  Updates the settings of the project with ID `project_id` from `attrs` and records
  `project_settings_changed` with the fields that changed.

  `allowed` lists the fields the calling form edits; a key of `attrs` outside it returns
  `{:error, :protected}` and writes nothing. Keys may be atoms or strings, as forms send them.
  `attributes` is merged into the persisted embed, so omitted attribute fields keep their
  values. An update that changes nothing records no event.
  """
  @spec update_project_settings(Context.t(), pos_integer(), map(), [atom()]) ::
          {:ok, %Project{}} | {:error, command_error()}
  def update_project_settings(%Context{} = context, project_id, attrs, allowed)
      when is_integer(project_id) and is_map(attrs) and is_list(allowed) do
    case allowed -- Settings.settings_fields() do
      [] -> :ok
      fields -> raise ArgumentError, "not project settings fields: #{inspect(fields)}"
    end

    with :ok <- Settings.check_keys(attrs, allowed) do
      change_settings(context, project_id, fn project ->
        project |> Settings.changeset(attrs) |> Repo.update()
      end)
    end
  end

  def update_project_settings(_context, _project_id, _attrs, _allowed),
    do: {:error, :invalid_request}

  @doc """
  Returns every project field a settings command may write, for callers that edit any setting
  (Scenario directives).
  """
  @spec project_settings_fields() :: [atom()]
  def project_settings_fields, do: Settings.settings_fields()

  @doc """
  Enables activation points (triggers) for the project with ID `project_id` and records
  `activation_settings_changed`. A project that already allows them records nothing.
  """
  @spec enable_triggers(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def enable_triggers(%Context{} = context, project_id) when is_integer(project_id) do
    change_settings(
      context,
      project_id,
      fn project ->
        project |> Project.changeset(%{allow_triggers: true}) |> Repo.update()
      end,
      event: :activation_settings_changed
    )
  end

  def enable_triggers(_context, _project_id), do: {:error, :invalid_request}

  @doc """
  Moves the project with ID `project_id` and its product templates from the legacy learning model
  to LKT-AOA, and records the change with the number of templates in `blueprint_count`.

  Only an author with access to the project may upgrade (`:not_authorized`); a project that is
  not active or already upgraded returns `:not_upgradable`. Course sections, content, and learner
  proficiency are unchanged.
  """
  @spec upgrade_learning_model(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def upgrade_learning_model(%Context{} = context, project_id) when is_integer(project_id) do
    change_settings(context, project_id, fn project ->
      with :ok <- project_author(context, project),
           {:ok, {upgraded, blueprint_count}} <- Settings.upgrade_learning_model(project) do
        {:ok, upgraded, %{blueprint_count: blueprint_count}}
      end
    end)
  end

  def upgrade_learning_model(_context, _project_id), do: {:error, :invalid_request}

  @doc """
  Creates the survey page that students take before starting the course, links it to the
  project with ID `project_id`, and records the change. Returns the survey revision, or an
  error message when the project already has a survey.
  """
  @spec create_project_survey(Context.t(), pos_integer()) ::
          {:ok, Oli.Resources.Revision.t()} | {:error, command_error()}
  def create_project_survey(%Context{author_id: author_id} = context, project_id)
      when is_integer(project_id) and is_integer(author_id) do
    Repo.transaction(fn ->
      with {:ok, before} <- Projects.lock_project(project_id),
           {:ok, {updated, revision}} <- Settings.create_survey(before, author_id),
           :ok <- record_settings(context, :project_settings_changed, before, updated, %{}) do
        revision
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def create_project_survey(_context, _project_id), do: {:error, :invalid_request}

  @doc """
  Unlinks and deletes the survey page of the project with ID `project_id`, and records the
  change. Returns an error message when the project has no survey.
  """
  @spec delete_project_survey(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def delete_project_survey(%Context{} = context, project_id) when is_integer(project_id) do
    change_settings(context, project_id, &Settings.delete_survey/1)
  end

  def delete_project_survey(_context, _project_id), do: {:error, :invalid_request}

  @doc """
  Writes the settings an archive import learns only after creating the project: its custom
  labels and its survey page. The import's `project_imported` event covers them, so no event is
  recorded.

  Accepts only `customizations` and `required_survey_resource_id` (`:protected` otherwise), and
  only inside the transaction of the import that recorded `project_imported` for this project
  under `context` (`:not_importing` otherwise).
  """
  @spec complete_import(Context.t(), %Project{}, map()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def complete_import(%Context{} = context, %Project{} = project, attrs) when is_map(attrs) do
    with :ok <- Settings.check_keys(attrs, Settings.import_fields()),
         :ok <- importing(context, project.id) do
      project |> Project.changeset(attrs) |> Repo.update()
    end
  end

  def complete_import(_context, _project, _attrs), do: {:error, :invalid_request}

  # The ingest builds one context per import, so its operation ID identifies the import that
  # created the project; an earlier import of the same archive has another operation ID.
  defp importing(%Context{operation_id: operation_id}, project_id) do
    query =
      from(e in LogEvent,
        where:
          e.project_id == ^project_id and e.event_type == :project_imported and
            e.operation_id == ^operation_id
      )

    case Repo.in_transaction?() and Repo.exists?(query) do
      true -> :ok
      false -> {:error, :not_importing}
    end
  end

  # Locks the project, applies `change`, and records the settings that changed. `change` returns
  # `{:ok, project}`, `{:ok, project, details}`, or `{:error, reason}`.
  defp change_settings(context, project_id, change, opts \\ []) do
    event_type = Keyword.get(opts, :event, :project_settings_changed)

    Repo.transaction(fn ->
      with {:ok, before} <- Projects.lock_project(project_id),
           {:ok, updated, details} <- with_details(change.(before)),
           :ok <- record_settings(context, event_type, before, updated, details) do
        updated
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp with_details({:ok, updated}), do: {:ok, updated, %{}}
  defp with_details({:ok, _updated, _details} = result), do: result
  defp with_details({:error, _reason} = error), do: error

  defp record_settings(context, event_type, before, updated, details) do
    {policy, key} =
      case event_type do
        :project_settings_changed -> {Fields.project_settings(), "settings_changed"}
        :activation_settings_changed -> {%{allow_triggers: :value}, "activation_settings_changed"}
      end

    case Changes.diff(Settings.view(before), Settings.view(updated), policy) do
      changes when map_size(changes) == 0 ->
        :ok

      changes ->
        record(context, %{
          event_type: event_type,
          entity: {:project, updated.id, updated},
          scope: %{project_id: updated.id},
          event_key: "project:#{updated.id}:#{key}",
          changes: changes,
          details: details
        })
    end
  end

  defp project_author(%Context{actor_type: :author, author_id: author_id}, project) do
    case Repo.get(Author, author_id) do
      %Author{} = author ->
        case Accounts.can_access?(author, project) do
          true -> :ok
          false -> {:error, :not_authorized}
        end

      nil ->
        {:error, :not_authorized}
    end
  end

  defp project_author(_context, _project), do: {:error, :not_authorized}

  ## Alternatives groups

  @alternatives_type_id Oli.Resources.ResourceType.id_for_alternatives()

  @doc """
  Creates an alternatives group in the project with slug `project_slug` and records it as added
  to `alternatives_groups`. `attrs` are the revision attributes (`title`, `content`). Returns the
  group's revision or the editor's error, as before.
  """
  @spec create_alternatives_group(Context.t(), String.t(), %Author{}, map()) ::
          {:ok, Oli.Resources.Revision.t()} | {:error, term()}
  def create_alternatives_group(%Context{} = context, project_slug, %Author{} = author, attrs) do
    Repo.transaction(fn ->
      with {:ok, group} <-
             Oli.Authoring.Editing.ResourceEditor.create(
               project_slug,
               author,
               @alternatives_type_id,
               attrs
             ),
           :ok <- record_group(context, project_slug, group, nil, group) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Applies `update` to the alternatives group with resource ID `resource_id` and records the
  group's title, strategy, and options before and after. An update that changes none of them
  records nothing. Returns the new revision or the editor's error, as before.
  """
  @spec edit_alternatives_group(Context.t(), String.t(), pos_integer(), %Author{}, map()) ::
          {:ok, Oli.Resources.Revision.t()} | {:error, term()}
  def edit_alternatives_group(%Context{} = context, project_slug, resource_id, author, update) do
    Repo.transaction(fn ->
      before = Oli.Publishing.AuthoringResolver.from_resource_id(project_slug, resource_id)

      with {:ok, group} <-
             Oli.Authoring.Editing.ResourceEditor.edit(project_slug, resource_id, author, update),
           :ok <- record_group(context, project_slug, group, before, group) do
        group
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  @doc """
  Moves option `option_id` of the group with resource ID `resource_id` (found in `groups`) to
  `drop_index`, and records the new option order. Returns what
  `Oli.Authoring.Editing.AlternativesOptionEditor.move_to/6` returns, as before.
  """
  @spec move_alternatives_option(
          Context.t(),
          String.t(),
          %Author{},
          [map()],
          integer() | String.t(),
          String.t(),
          integer() | String.t()
        ) :: {:ok, [map()], map()} | {:ok, :unchanged} | {:error, term()}
  def move_alternatives_option(
        %Context{} = context,
        project_slug,
        author,
        groups,
        resource_id,
        option_id,
        drop_index
      ) do
    Repo.transaction(fn ->
      case Oli.Authoring.Editing.AlternativesOptionEditor.move_to(
             project_slug,
             author,
             groups,
             resource_id,
             option_id,
             drop_index
           ) do
        {:ok, :unchanged} ->
          :unchanged

        {:ok, updated_groups, group} ->
          before = Enum.find(groups, &(&1.resource_id == group.resource_id))

          case record_group(context, project_slug, group, before, group) do
            :ok -> {updated_groups, group}
            {:error, reason} -> Repo.rollback(reason)
          end

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, :unchanged} -> {:ok, :unchanged}
      {:ok, {updated_groups, group}} -> {:ok, updated_groups, group}
      error -> error
    end
  end

  defp record_group(context, project_slug, group, before, after_group) do
    old = before && group_summary(before)
    new = group_summary(after_group)

    changes =
      case old do
        nil ->
          %{"alternatives_groups" => %{"operation" => "added", "after" => [new]}}

        ^new ->
          %{}

        old ->
          %{"alternatives_groups" => %{"operation" => "set", "before" => [old], "after" => [new]}}
      end

    case map_size(changes) do
      0 ->
        :ok

      _ ->
        project = Course.get_project_by_slug(project_slug)

        record(context, %{
          event_type: :project_settings_changed,
          entity: {:project, project.id, project},
          scope: %{project_id: project.id},
          event_key: "project:#{project.id}:settings_changed",
          changes: changes,
          details: %{alternatives_group_id: group.resource_id}
        })
    end
  end

  defp group_summary(group) do
    content = group.content || %{}

    %{
      "resource_id" => group.resource_id,
      "title" => group.title,
      "strategy" => content["strategy"],
      "options" => Enum.map(content["options"] || [], &%{"id" => &1["id"], "name" => &1["name"]})
    }
  end

  ## Content and media removal

  @doc """
  Removes a page or container from `container` and marks it as deleted, with the activities it
  embeds, and records `authoring_content_removed` with the IDs of those activities. Fails while
  another author holds the page's lock. Broadcasts the container after commit.
  """
  @spec remove_from_curriculum(Context.t(), Revision.t(), Project.t(), Author.t(), String.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def remove_from_curriculum(
        %Context{} = context,
        %Revision{} = container,
        %Project{} = project,
        %Author{} = author,
        revision_slug
      )
      when is_binary(revision_slug) do
    resource_ids = resource_ids_for_slug(revision_slug)

    project
    |> removing(context, resource_ids, [cascade: true], fn ->
      Content.remove_child(container, project, author, revision_slug)
    end)
    |> tap(fn
      {:ok, _} -> ContainerEditor.broadcast_update(container.resource_id, project.slug)
      _error -> :ok
    end)
  end

  def remove_from_curriculum(_context, _container, _project, _author, _revision_slug),
    do: {:error, :invalid_request}

  @doc """
  Marks a page that belongs to no container as deleted and records `authoring_content_removed`.
  Takes no lock and leaves the page's activities as they are, as before.
  """
  @spec delete_unattached_page(Context.t(), Project.t(), String.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_unattached_page(%Context{} = context, %Project{} = project, revision_slug)
      when is_binary(revision_slug) do
    removing(project, context, resource_ids_for_slug(revision_slug), [], fn ->
      Content.delete_unattached(project.slug, revision_slug)
    end)
  end

  def delete_unattached_page(_context, _project, _revision_slug), do: {:error, :invalid_request}

  @doc """
  Deletes an activity within the lock of `lock_id` and records `bank_question_deleted` for a
  banked activity or `authoring_content_removed` otherwise. Keeps the activity editor's
  results and errors.
  """
  @spec delete_activity(Context.t(), String.t(), term(), term(), Author.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_activity(
        %Context{} = context,
        project_slug,
        lock_id,
        activity_id,
        %Author{} = author
      )
      when is_binary(project_slug) do
    removing(project_slug, context, resource_ids([activity_id]), [], fn ->
      ActivityEditor.delete(project_slug, lock_id, activity_id, author)
    end)
  end

  def delete_activity(_context, _project_slug, _lock_id, _activity_id, _author),
    do: {:error, :invalid_request}

  @doc """
  Deletes several activities all or nothing, and records one event per activity as
  `delete_activity/5` does, under the same operation.
  """
  @spec delete_activities(Context.t(), String.t(), [term()], Author.t()) ::
          {:ok, term()} | {:error, command_error()}
  def delete_activities(%Context{} = context, project_slug, activity_ids, %Author{} = author)
      when is_binary(project_slug) and is_list(activity_ids) do
    removing(project_slug, context, resource_ids(activity_ids), [], fn ->
      ActivityEditor.delete_bulk(project_slug, activity_ids, author)
    end)
  end

  def delete_activities(_context, _project_slug, _activity_ids, _author),
    do: {:error, :invalid_request}

  @doc "Deletes an alternatives group and records `authoring_content_removed`."
  @spec delete_alternatives_group(Context.t(), String.t(), pos_integer(), Author.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_alternatives_group(%Context{} = context, project_slug, resource_id, author)
      when is_binary(project_slug) do
    removing(project_slug, context, resource_ids([resource_id]), [], fn ->
      Content.delete_alternatives_group(project_slug, resource_id, author)
    end)
  end

  def delete_alternatives_group(_context, _project_slug, _resource_id, _author),
    do: {:error, :invalid_request}

  @doc "Deletes a bibliography entry and records `authoring_content_removed`."
  @spec delete_bib_entry(Context.t(), String.t(), term(), Author.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_bib_entry(%Context{} = context, project_slug, resource_id, author)
      when is_binary(project_slug) do
    removing(project_slug, context, resource_ids([resource_id]), [], fn ->
      Content.delete_bib_entry(project_slug, resource_id, author)
    end)
  end

  def delete_bib_entry(_context, _project_slug, _resource_id, _author),
    do: {:error, :invalid_request}

  @doc """
  Marks media items as deleted and records one `media_deleted` per item that was not deleted
  yet, scoped to the item's own project. Items are selected by ID only, as before; the stored
  files are kept. Returns the number of selected items.
  """
  @spec delete_media(Context.t(), String.t(), [term()]) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def delete_media(%Context{} = context, project_slug, media_ids)
      when is_binary(project_slug) and is_list(media_ids) do
    Repo.transaction(fn ->
      with {:ok, items} <- Content.delete_media(project_slug, media_ids),
           :ok <- record_all(items, &record_media_deleted(context, &1)) do
        length(items)
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def delete_media(_context, _project_slug, _media_ids), do: {:error, :invalid_request}

  # Locks the working-publication mappings of `resource_ids`, reads their revisions, runs
  # `write`, and records a removal for each resource that `write` deleted. With `cascade: true`,
  # the event also lists the embedded activities that the write deleted.
  defp removing(project_slug, context, resource_ids, opts, write) when is_binary(project_slug) do
    case Course.get_project_by_slug(project_slug) do
      # The write reports a missing project with its usual error
      nil -> write.()
      project -> removing(project, context, resource_ids, opts, write)
    end
  end

  defp removing(%Project{} = project, context, resource_ids, opts, write) do
    Repo.transaction(fn ->
      lock_working_mappings(project, resource_ids)
      before = latest_revisions(project, resource_ids)
      embedded = if opts[:cascade], do: embedded_activities(project, before), else: %{}

      with {:ok, result} <- write.(),
           after_state = latest_revisions(project, resource_ids),
           removed_embedded = removed(embedded, latest_revisions(project, Map.keys(embedded))),
           :ok <-
             record_all(resource_ids, fn id ->
               record_removal(context, project, before[id], after_state[id], removed_embedded)
             end) do
        result
      else
        {:error, reason} -> Repo.rollback(reason)
        other -> Repo.rollback(other)
      end
    end)
  end

  defp resource_ids_for_slug(revision_slug) do
    case Oli.Resources.get_resource_from_slug(revision_slug) do
      nil -> []
      resource -> [resource.id]
    end
  end

  # Client IDs arrive as integers or strings; anything else is left to the write to reject.
  defp resource_ids(ids) do
    Enum.flat_map(ids, fn
      id when is_integer(id) ->
        [id]

      id when is_binary(id) ->
        case Integer.parse(id) do
          {id, ""} -> [id]
          _ -> []
        end

      _ ->
        []
    end)
  end

  defp lock_working_mappings(_project, []), do: :ok

  defp lock_working_mappings(project, resource_ids) do
    from(mapping in PublishedResource,
      join: publication in Publication,
      on: publication.id == mapping.publication_id,
      where:
        publication.project_id == ^project.id and is_nil(publication.published) and
          mapping.resource_id in ^resource_ids,
      order_by: mapping.resource_id,
      lock: "FOR UPDATE OF p0"
    )
    |> Repo.all()

    :ok
  end

  defp latest_revisions(_project, []), do: %{}

  defp latest_revisions(project, resource_ids) do
    project.slug
    |> AuthoringResolver.from_resource_id(resource_ids)
    |> Enum.reject(&is_nil/1)
    |> Map.new(&{&1.resource_id, &1})
  end

  # Activities embedded in the pages about to be removed, with their current revisions.
  defp embedded_activities(project, revisions) do
    ids =
      revisions
      |> Map.values()
      |> Enum.flat_map(&(&1.content |> Editing.Utils.activity_references() |> MapSet.to_list()))
      |> Enum.uniq()

    latest_revisions(project, ids)
  end

  defp removed(before, after_state) do
    before
    |> Enum.filter(fn {id, revision} ->
      not revision.deleted and match?(%Revision{deleted: true}, after_state[id])
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp record_removal(context, project, %Revision{deleted: false} = before, after_rev, embedded)
       when is_struct(after_rev, Revision) and after_rev.deleted do
    removed_activity_ids =
      before.content
      |> Editing.Utils.activity_references()
      |> MapSet.to_list()
      |> Enum.filter(&(&1 in embedded))
      |> Enum.sort()

    record(context, %{
      event_type: removal_event_type(before),
      entity: {:resource, before.resource_id, %{title: before.title, slug: before.slug}},
      scope: %{project_id: project.id, resource_id: before.resource_id},
      refs: [
        %{role: :previous, type: :revision, id: before.id, label: before.title},
        %{role: :resulting, type: :revision, id: after_rev.id, label: after_rev.title}
      ],
      changes: Changes.diff(%{deleted: false}, %{deleted: true}, Fields.authoring_content()),
      details:
        case removed_activity_ids do
          [] -> %{}
          ids -> %{removed_activity_ids: ids}
        end,
      event_key: "resource:#{before.resource_id}:removed"
    })
  end

  # Missing, already deleted, or not deleted by the write: nothing to record
  defp record_removal(_context, _project, _before, _after, _embedded), do: :ok

  defp removal_event_type(%Revision{scope: :banked, resource_type_id: type_id}) do
    case type_id == Oli.Resources.ResourceType.id_for_activity() do
      true -> :bank_question_deleted
      false -> :authoring_content_removed
    end
  end

  defp removal_event_type(_revision), do: :authoring_content_removed

  defp record_media_deleted(_context, %MediaItem{deleted: true}), do: :ok

  defp record_media_deleted(context, %MediaItem{} = item) do
    record(context, %{
      event_type: :media_deleted,
      entity: {:media_item, item.id, %{title: item.file_name}},
      scope: %{project_id: item.project_id},
      changes: Changes.diff(%{deleted: false}, %{deleted: true}, Fields.authoring_content()),
      details: %{file_name: item.file_name, mime_type: item.mime_type},
      event_key: "media:#{item.id}:deleted"
    })
  end

  defp record_all(items, record_one) do
    Enum.reduce_while(items, :ok, fn item, :ok ->
      case record_one.(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  ## Collaborators

  @doc """
  Adds `author` to `project` as an accepted collaborator (the owner when the project has no
  collaborators yet) and records `project_collaborator_changed`.
  """
  @spec add_collaborator(Context.t(), %Author{}, %Project{}) ::
          {:ok, %AuthorProject{}} | {:error, command_error()}
  def add_collaborator(%Context{} = context, %Author{} = author, %Project{} = project) do
    Repo.transaction(fn ->
      with {:ok, author_project} <- Projects.insert_collaborator(author, project, :accepted),
           :ok <- record_collaborator(context, project, author_project, nil) do
        author_project
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  def add_collaborator(_context, _author, _project), do: {:error, :invalid_request}

  @doc """
  Invites `email` to collaborate on the project with `project_slug`: creates the invited author
  when there is none (`account_created`, with `context` as the inviter), the pending
  collaboration (`project_collaborator_changed`), and the invitation token, in one transaction.
  The email is sent after the commit.

  Returns `{:ok, author_project}` or `{:error, message}` with the message shown to the inviter,
  as before.
  """
  @spec invite_collaborator(Context.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, %AuthorProject{}} | {:error, term()}
  def invite_collaborator(%Context{} = context, inviter_name, inviter_email, email, project_slug) do
    result =
      Repo.transaction(fn ->
        with {:ok, project} <-
               project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
             {:ok, author} <- invited_author(context, email),
             {:ok, author_project} <-
               Projects.insert_collaborator(author, project, :pending_confirmation),
             :ok <- record_collaborator(context, project, author_project, nil),
             {:ok, email_data} <- insert_invitation_token(author, project_slug) do
          {author_project, email_data, project}
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)

    with {:ok, {author_project, email_data, project}} <- result,
         {:ok, _mail} <-
           Collaborators.send_email_invitation(
             email_data,
             inviter_name,
             inviter_email,
             project.title
           ) do
      {:ok, author_project}
    end
  end

  defp invited_author(context, email) do
    case Accounts.get_author_by_email(email) do
      nil ->
        case Accounts.Audited.invite_author_multi(Multi.new(), :author, context, email)
             |> Repo.transaction() do
          {:ok, %{author: author}} ->
            {:ok, author}

          {:error, _step, _reason, _changes} ->
            {:error, "Unable to create invitation for new author"}
        end

      author ->
        {:ok, author}
    end
  end

  defp insert_invitation_token(author, project_slug) do
    {token, author_token} =
      AuthorToken.build_email_token(author, "collaborator_invitation:#{project_slug}")

    with {:ok, _} <- Repo.insert(author_token) do
      {:ok, %{sent_to: author_token.sent_to, token: token}}
    end
  end

  @doc """
  Adds to `multi` the answer of the invited author to a pending collaboration
  (`:accepted` or `:rejected`) and records `project_collaborator_changed` with the invited
  author as actor. A collaboration that is no longer pending is left unchanged, without an event.
  The result under `name` is the collaboration.
  """
  @spec respond_to_invitation_multi(
          Multi.t(),
          Multi.name(),
          Context.t(),
          {pos_integer(), pos_integer(), :accepted | :rejected}
        ) :: Multi.t()
  def respond_to_invitation_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {author_id, project_id, status}
      )
      when status in [:accepted, :rejected] do
    Multi.run(multi, name, fn _repo, _changes ->
      respond(context, author_id, project_id, status)
    end)
  end

  def respond_to_invitation_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  @doc "Runs `respond_to_invitation_multi/4` in its own transaction."
  @spec respond_to_invitation(Context.t(), {pos_integer(), pos_integer(), :accepted | :rejected}) ::
          {:ok, %AuthorProject{}} | {:error, command_error()}
  def respond_to_invitation(context, args) do
    Multi.new()
    |> respond_to_invitation_multi(:author_project, context, args)
    |> Repo.transaction()
    |> case do
      {:ok, %{author_project: author_project}} -> {:ok, author_project}
      {:error, _step, reason, _changes} -> {:error, reason}
    end
  end

  defp respond(context, author_id, project_id, status) do
    with {:ok, author_project} <- Projects.lock_collaborator(author_id, project_id) do
      case author_project.status do
        :pending_confirmation ->
          with {:ok, updated} <- Projects.update_collaborator_status(author_project, status),
               project <- Repo.get!(Project, project_id),
               :ok <- record_collaborator(context, project, updated, author_project) do
            {:ok, updated}
          end

        _other ->
          {:ok, author_project}
      end
    end
  end

  @doc """
  Adds to `multi` the removal of the author with `author_email` from the project with
  `project_slug` and records `project_collaborator_changed`. The owner cannot be removed, as
  before. The result under `name` is the removed collaboration.
  """
  @spec remove_collaborator_multi(Multi.t(), Multi.name(), Context.t(), {String.t(), String.t()}) ::
          Multi.t()
  def remove_collaborator_multi(
        %Multi{} = multi,
        name,
        %Context{} = context,
        {author_email, project_slug}
      )
      when is_binary(author_email) and is_binary(project_slug) do
    Multi.run(multi, name, fn _repo, _changes ->
      with {:ok, author} <-
             author_email
             |> Accounts.get_author_by_email()
             |> found("An author with that email was not found."),
           {:ok, project} <-
             project_slug |> Course.get_project_by_slug() |> found("The project was not found."),
           {:ok, author_project} <- locked_collaborator(author.id, project.id),
           :ok <- not_owner(author_project),
           {:ok, _deleted} <- Projects.delete_collaborator(author_project),
           :ok <- record_collaborator(context, project, nil, author_project) do
        {:ok, author_project}
      end
    end)
  end

  def remove_collaborator_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)

  defp locked_collaborator(author_id, project_id) do
    case Projects.lock_collaborator(author_id, project_id) do
      {:ok, author_project} -> {:ok, author_project}
      {:error, :not_found} -> {:error, "The author is not a collaborator on the project."}
    end
  end

  defp not_owner(author_project) do
    case Projects.role_type(author_project) do
      "owner" -> {:error, "That author is the project owner."}
      _ -> :ok
    end
  end

  defp record_collaborator(context, project, after_state, before_state) do
    author_id = (after_state || before_state).author_id

    changes =
      Changes.diff(
        collaborator_state(before_state),
        collaborator_state(after_state),
        @collaborator_fields
      )

    record(context, %{
      event_type: :project_collaborator_changed,
      entity: {:project, project.id, project},
      scope: %{project_id: project.id},
      affected: {:author, author_id},
      event_key: "project:#{project.id}:collaborator:#{author_id}:changed",
      changes: changes
    })
  end

  defp collaborator_state(nil), do: nil

  defp collaborator_state(%AuthorProject{} = author_project),
    do: %{status: author_project.status, role: Projects.role_type(author_project)}

  ## Shared

  defp found(nil, message), do: {:error, message}
  defp found(value, _message), do: {:ok, value}

  defp record(context, proposal) do
    with {:ok, changeset} <- Auditing.build(context, proposal),
         {:ok, _event} <- Auditing.insert(changeset) do
      :ok
    end
  end
end
