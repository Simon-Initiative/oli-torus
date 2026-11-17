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

  Alternatives group changes record `project_settings_changed` with the group's title, strategy,
  and options before and after.

  Removing a page, container, activity, alternatives group, or bibliography entry records
  `authoring_content_removed` (`bank_question_deleted` for a banked activity) with the previous
  and resulting revisions; deleting media records `media_deleted` per item. Content that was
  already deleted records nothing.

  Commands do not authorize the actor; callers keep their existing authorization. Checks that
  lived in the migrated functions (the owner cannot be removed, only project authors upgrade
  the learning model) run inside the transaction.

  This module validates arguments and documents each command; the private modules under
  `Oli.Authoring.Audited` implement them, one per section below.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Accounts.Author
  alias Oli.Auditing.Context
  alias Oli.Authoring.Audited.{Alternatives, Collaborators, Content, Projects, Settings}
  alias Oli.Authoring.Authors.AuthorProject
  alias Oli.Authoring.Course.Project
  alias Oli.Repo
  alias Oli.Resources.Revision

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
    Projects.create_project(context, title, author, attrs, opts)
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
    Projects.import_project(context, title, author, learning_model_version, attrs)
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
    Projects.duplicate_project(context, project_slug, author, opts)
  end

  def duplicate_project(_context, _project_slug, _author, _opts), do: {:error, :invalid_request}

  @doc """
  Marks the project with ID `project_id` deleted and records `project_deleted`. A project that
  is already deleted returns it unchanged, without an event.
  """
  @spec delete_project(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def delete_project(%Context{} = context, project_id) when is_integer(project_id),
    do: Projects.delete_project(context, project_id)

  def delete_project(_context, _project_id), do: {:error, :invalid_request}

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
    Settings.update_project_settings(context, project_id, attrs, allowed)
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
  def enable_triggers(%Context{} = context, project_id) when is_integer(project_id),
    do: Settings.enable_triggers(context, project_id)

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
  def upgrade_learning_model(%Context{} = context, project_id) when is_integer(project_id),
    do: Settings.upgrade_learning_model(context, project_id)

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
    Settings.create_project_survey(context, project_id)
  end

  def create_project_survey(_context, _project_id), do: {:error, :invalid_request}

  @doc """
  Unlinks and deletes the survey page of the project with ID `project_id`, and records the
  change. Returns an error message when the project has no survey.
  """
  @spec delete_project_survey(Context.t(), pos_integer()) ::
          {:ok, %Project{}} | {:error, command_error()}
  def delete_project_survey(%Context{} = context, project_id) when is_integer(project_id),
    do: Settings.delete_project_survey(context, project_id)

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
  def complete_import(%Context{} = context, %Project{} = project, attrs) when is_map(attrs),
    do: Settings.complete_import(context, project, attrs)

  def complete_import(_context, _project, _attrs), do: {:error, :invalid_request}

  ## Alternatives groups

  @doc """
  Creates an alternatives group in the project with slug `project_slug` and records it as added
  to `alternatives_groups`. `attrs` are the revision attributes (`title`, `content`). Returns the
  group's revision or the editor's error, as before.
  """
  @spec create_alternatives_group(Context.t(), String.t(), %Author{}, map()) ::
          {:ok, Oli.Resources.Revision.t()} | {:error, term()}
  def create_alternatives_group(%Context{} = context, project_slug, %Author{} = author, attrs),
    do: Alternatives.create_alternatives_group(context, project_slug, author, attrs)

  @doc """
  Applies `update` to the alternatives group with resource ID `resource_id` and records the
  group's title, strategy, and options before and after. An update that changes none of them
  records nothing. Returns the new revision or the editor's error, as before.
  """
  @spec edit_alternatives_group(Context.t(), String.t(), pos_integer(), %Author{}, map()) ::
          {:ok, Oli.Resources.Revision.t()} | {:error, term()}
  def edit_alternatives_group(%Context{} = context, project_slug, resource_id, author, update),
    do: Alternatives.edit_alternatives_group(context, project_slug, resource_id, author, update)

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
    Alternatives.move_alternatives_option(
      context,
      project_slug,
      author,
      groups,
      resource_id,
      option_id,
      drop_index
    )
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
    Content.remove_from_curriculum(context, container, project, author, revision_slug)
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
    Content.delete_unattached_page(context, project, revision_slug)
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
    Content.delete_activity(context, project_slug, lock_id, activity_id, author)
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
    Content.delete_activities(context, project_slug, activity_ids, author)
  end

  def delete_activities(_context, _project_slug, _activity_ids, _author),
    do: {:error, :invalid_request}

  @doc "Deletes an alternatives group and records `authoring_content_removed`."
  @spec delete_alternatives_group(Context.t(), String.t(), pos_integer(), Author.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_alternatives_group(%Context{} = context, project_slug, resource_id, author)
      when is_binary(project_slug) do
    Content.delete_alternatives_group(context, project_slug, resource_id, author)
  end

  def delete_alternatives_group(_context, _project_slug, _resource_id, _author),
    do: {:error, :invalid_request}

  @doc "Deletes a bibliography entry and records `authoring_content_removed`."
  @spec delete_bib_entry(Context.t(), String.t(), term(), Author.t()) ::
          {:ok, Revision.t()} | {:error, command_error()}
  def delete_bib_entry(%Context{} = context, project_slug, resource_id, author)
      when is_binary(project_slug) do
    Content.delete_bib_entry(context, project_slug, resource_id, author)
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
    Content.delete_media(context, project_slug, media_ids)
  end

  def delete_media(_context, _project_slug, _media_ids), do: {:error, :invalid_request}

  ## Collaborators

  @doc """
  Adds `author` to `project` as an accepted collaborator (the owner when the project has no
  collaborators yet) and records `project_collaborator_changed`.
  """
  @spec add_collaborator(Context.t(), %Author{}, %Project{}) ::
          {:ok, %AuthorProject{}} | {:error, command_error()}
  def add_collaborator(%Context{} = context, %Author{} = author, %Project{} = project) do
    Collaborators.add_collaborator(context, author, project)
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
    Collaborators.invite_collaborator(context, inviter_name, inviter_email, email, project_slug)
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
      Collaborators.respond_to_invitation(context, author_id, project_id, status)
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
      Collaborators.remove_collaborator(context, author_email, project_slug)
    end)
  end

  def remove_collaborator_multi(%Multi{} = multi, name, _context, _args),
    do: Multi.error(multi, name, :invalid_request)
end
