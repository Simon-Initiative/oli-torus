defmodule Oli.Delivery.Sections.Audited do
  @moduledoc """
  Application boundary for audited changes to sections and products (course section
  templates): their lifecycle, settings, discussion configuration, remixes, publication
  updates, and schedules.

  Each command writes its change and its audit events in one transaction, so a change is never
  committed without its events and a failed or rolled-back change records nothing. Sections of
  type `:blueprint` record `product_*` events, which the Audit Log labels "Template"; other
  sections record `section_*` events.

  Settings commands write only the fields the caller allows, the fields its form renders for
  that user, and record one event per family that changed (`<kind>_settings_changed`,
  `publication_update_policy_changed`, the DOT events, `discussion_settings_changed`,
  `notes_settings_changed`); a save that changes nothing records nothing.

  Commands do not authorize the actor: callers keep their existing authorization, and checks
  that already lived in a moved function (such as the course builder's creation rights) still
  run inside the transaction. The writes live in private modules under this namespace, so this
  module is the only way to make them.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Oli.Auditing.Context
  alias Oli.Delivery.SectionCreationRequest
  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.Author
  alias Oli.Delivery.Remix.State, as: RemixState

  alias Oli.Delivery.Sections.Audited.{
    Discussions,
    Lifecycle,
    PublicationUpdates,
    Remix,
    Schedule
  }

  alias Oli.Delivery.Sections.Audited.SectionSettings
  alias Oli.Publishing.Publications.Publication
  alias Oli.Resources.Collaboration.CollabSpaceConfig

  @type command_error ::
          :invalid_request
          | :not_found
          | :nested_transaction
          | :unauthorized
          | Ecto.Changeset.t()
          | Oli.Auditing.Error.t()
          | term()

  @doc """
  Creates a section from a course builder request and records `section_created`.

  Keeps the course builder's behavior: the request's actor is reloaded and authorized for its
  delivery mode, an LTI context that already has a section for the authorized deployment
  returns that section without creating or recording anything, and the source (publication,
  product, or previous section) is resolved inside the creation transaction. A user actor is
  enrolled as instructor; that enrollment is part of the creation, not a separate event.

  `context` must name the request's actor; otherwise the command returns `:invalid_request`.
  Returns `{:ok, section_id, section_slug}`.
  """
  @spec create_section(Context.t(), SectionCreationRequest.t()) ::
          {:ok, pos_integer(), String.t()} | {:error, command_error()}
  def create_section(%Context{} = context, %SectionCreationRequest{} = request),
    do: Lifecycle.create_section(context, request)

  def create_section(_context, _request), do: {:error, :invalid_request}

  @doc """
  Creates a section from `publication` with `attrs` and records `section_created`, for
  creation paths outside the course builder (independent instructors, Scenarios, automation
  setup). It runs in the caller's transaction when there is one.

  Options:
    * `:rebuild` - `true` rebuilds the contained pages and objectives (default `false`)
    * `:enroll` - a `User` enrolled as instructor (default none)
    * `:post_processing` - the post-processing steps to apply, such as `:all` (default none)
  """
  @spec create_section_from_publication(Context.t(), Publication.t(), map(), keyword()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_section_from_publication(context, publication, attrs, opts \\ [])

  def create_section_from_publication(
        %Context{} = context,
        %Publication{} = publication,
        attrs,
        opts
      )
      when is_map(attrs) and is_list(opts),
      do: Lifecycle.create_section_from_publication(context, publication, attrs, opts)

  def create_section_from_publication(_context, _publication, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Creates a section from `product` with `attrs`, rebuilds its contained pages and objectives,
  and records `section_created` with the product's ID, for creation paths outside the course
  builder. It runs in the caller's transaction when there is one.

  Options: `:enroll` (a `User` enrolled as instructor) and `:post_processing`, as in
  `create_section_from_publication/4`.
  """
  @spec create_section_from_product(Context.t(), Section.t(), map(), keyword()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_section_from_product(context, product, attrs, opts \\ [])

  def create_section_from_product(
        %Context{} = context,
        %Section{type: :blueprint} = product,
        attrs,
        opts
      )
      when is_map(attrs) and is_list(opts),
      do: Lifecycle.create_section_from_product(context, product, attrs, opts)

  def create_section_from_product(_context, _product, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Creates a product (course section template) from the latest publication of the project with
  `base_project_slug` and records `product_created`.

  `labels`, `hierarchy`, and `attrs` are the custom labels, the optional custom hierarchy, and
  the additional attributes `Oli.Delivery.Sections.Blueprint.create_blueprint/5` takes.
  """
  @spec create_product(Context.t(), String.t(), String.t(), map() | nil, term(), map()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_product(context, base_project_slug, title, labels, hierarchy \\ nil, attrs \\ %{})

  def create_product(%Context{} = context, base_project_slug, title, labels, hierarchy, attrs)
      when is_binary(base_project_slug) and is_map(attrs),
      do: Lifecycle.create_product(context, base_project_slug, title, labels, hierarchy, attrs)

  def create_product(_context, _slug, _title, _labels, _hierarchy, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Duplicates `product` with `attrs` and records `product_created` for the copy, with
  `creation_source: "product_copy"` and the source product's ID.
  """
  @spec duplicate_product(Context.t(), Section.t(), map()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def duplicate_product(context, product, attrs \\ %{})

  def duplicate_product(%Context{} = context, %Section{} = product, attrs) when is_map(attrs),
    do: Lifecycle.duplicate_product(context, product, attrs)

  def duplicate_product(_context, _product, _attrs), do: {:error, :invalid_request}

  @doc """
  Archives `section` (status `:archived`) and records `section_archived` or `product_archived`
  with the status before and after. A section already archived records nothing.
  """
  @spec archive_section(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def archive_section(%Context{} = context, %Section{} = section),
    do: Lifecycle.archive_section(context, section)

  def archive_section(_context, _section), do: {:error, :invalid_request}

  @doc """
  Deletes `section` (status `:deleted`; the row is kept) and records `section_deleted` or
  `product_deleted`. A section already deleted records nothing.
  """
  @spec delete_section(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def delete_section(%Context{} = context, %Section{} = section),
    do: Lifecycle.delete_section(context, section)

  def delete_section(_context, _section), do: {:error, :invalid_request}

  @doc """
  Writes the keys of `attrs` (atom or string keys, as a form submits them) named in `allowed`
  to `section` and records what changed: `<kind>_settings_changed` for the section settings,
  `<kind>_archived` or `<kind>_deleted` when the status moves to that value, and
  `publication_update_policy_changed` for `apply_major_updates`. Other keys of `attrs` are
  ignored, so a form writes only the fields it renders.

  `allowed` lists the fields the caller's form offers to the user; it may include payment and
  certificate fields, which are written without an event until their own events exist. Any
  other field (LTI service fields, system-derived fields, DOT settings) returns
  `:invalid_request`.
  """
  @spec update_section_settings(Context.t(), Section.t(), map(), [atom()]) ::
          {:ok, Section.t()} | {:error, command_error()}
  def update_section_settings(%Context{} = context, %Section{} = section, attrs, allowed)
      when is_map(attrs) and is_list(allowed),
      do:
        SectionSettings.update(
          context,
          section,
          attrs,
          allowed,
          SectionSettings.settings_fields()
        )

  def update_section_settings(_context, _section, _attrs, _allowed),
    do: {:error, :invalid_request}

  @doc """
  Writes the DOT settings of `attrs` named in `allowed` (`assistant_enabled`, `triggers_enabled`,
  `page_prompt_template`, `instructor_recommendations_enabled`,
  `instructor_recommendation_prompt_template`) and records `dot_settings_changed`,
  `activation_settings_changed`, or `instructor_ai_recommendation_changed` for each that
  changed. Prompts are recorded up to 2,000 characters, with `prompt_truncated` in the details
  when cut.
  """
  @spec update_section_dot(Context.t(), Section.t(), map(), [atom()]) ::
          {:ok, Section.t()} | {:error, command_error()}
  def update_section_dot(%Context{} = context, %Section{} = section, attrs, allowed)
      when is_map(attrs) and is_list(allowed),
      do: SectionSettings.update(context, section, attrs, allowed, SectionSettings.dot_fields())

  def update_section_dot(_context, _section, _attrs, _allowed), do: {:error, :invalid_request}

  @doc """
  Requires the students of `section` to take its base project's survey before starting, and
  records `<kind>_settings_changed`. Returns `:survey_already_required` when the section already
  requires one and `:no_project_survey` when the project has none.
  """
  @spec create_section_survey(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def create_section_survey(%Context{} = context, %Section{} = section),
    do: SectionSettings.create_survey(context, section)

  def create_section_survey(_context, _section), do: {:error, :invalid_request}

  @doc """
  Stops requiring the survey in `section` and records `<kind>_settings_changed`. Returns
  `:no_required_survey` when the section requires none.
  """
  @spec delete_section_survey(Context.t(), Section.t()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def delete_section_survey(%Context{} = context, %Section{} = section),
    do: SectionSettings.delete_survey(context, section)

  def delete_section_survey(_context, _section), do: {:error, :invalid_request}

  @doc """
  Changes the course discussion board of `section`: merges `config_changes` (fields of
  `CollabSpaceConfig`, such as `:status` or `:auto_accept`) into the root container's
  configuration and, when the status changes, sets `contains_discussions` to match. Records
  `discussion_settings_changed` for the section with the fields that changed.

  Returns the updated section and root section resource. A section without a root container
  returns `:not_found`.
  """
  @spec update_course_discussions(Context.t(), Section.t(), map()) ::
          {:ok, %{section: Section.t(), section_resource: struct()}}
          | {:error, command_error()}
  def update_course_discussions(%Context{} = context, %Section{} = section, config_changes)
      when is_map(config_changes),
      do: Discussions.update_course(context, section, config_changes)

  def update_course_discussions(_context, _section, _config_changes),
    do: {:error, :invalid_request}

  @doc """
  Writes `config_attrs` as the discussion configuration of the page with `resource_id` in
  `section`, sets `contains_discussions` to match an enabled or disabled status, and records
  `discussion_settings_changed` for the page.

  Returns the updated section and section resource.
  """
  @spec update_page_discussions(Context.t(), Section.t(), pos_integer(), map()) ::
          {:ok, %{section: Section.t(), section_resource: struct()}}
          | {:error, command_error()}
  def update_page_discussions(%Context{} = context, %Section{} = section, resource_id, attrs)
      when is_integer(resource_id) and is_map(attrs),
      do: Discussions.update_page(context, section, resource_id, attrs)

  def update_page_discussions(_context, _section, _resource_id, _attrs),
    do: {:error, :invalid_request}

  @doc """
  Enables notes on every page of `section` with `config`, or disables them with `:disabled`,
  and records one `notes_settings_changed` for the section with the number of pages written.
  Returns that number.
  """
  @spec set_section_notes(Context.t(), Section.t(), %CollabSpaceConfig{} | :disabled) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def set_section_notes(%Context{} = context, %Section{} = section, :disabled),
    do: Discussions.set_notes(context, section, :disabled)

  def set_section_notes(
        %Context{} = context,
        %Section{} = section,
        %CollabSpaceConfig{} = config
      ),
      do: Discussions.set_notes(context, section, config)

  def set_section_notes(_context, _section, _config), do: {:error, :invalid_request}

  @doc """
  Saves a remix: materializes draft containers, writes template container edits, rebuilds the
  curriculum and pinned publications of the remix state's section, and initializes the Deep
  Link selections of added pages, all in one transaction under the section lock.

  Records one `section_remix_saved` per curriculum entry whose parent, position, visibility,
  numbering, or source publication changed, including added and removed entries. `author`
  is the author the materialized containers and template edits are written as; the actor is
  `context`'s, so an instructor who is a `User` is recorded as such.

  Returns `{:ok, section}` with the section read again, or `{:error, reason}` with nothing
  written or recorded; `{:error, :nested_transaction}` inside another transaction.
  """
  @spec save_remix(Context.t(), RemixState.t(), Author.t() | nil) ::
          {:ok, Section.t()} | {:error, command_error()}
  def save_remix(%Context{} = context, %RemixState{} = state, author),
    do: Remix.save(context, state, author)

  def save_remix(_context, _state, _author), do: {:error, :invalid_request}

  @doc """
  Applies the publication with `publication_id` to `section`, keeping the section's own
  curriculum changes, in one transaction under the section lock.

  Records `publication_applied` with the previous and resulting publications when the
  section's publication of that project changes; re-applying the publication already in place
  records nothing. Section caches are cleared and progress is broadcast after the commit.

  Returns `{:ok, section}` or `{:error, reason}` with nothing written or recorded;
  `{:error, :nested_transaction}` inside another transaction.
  """
  @spec apply_publication_update(Context.t(), Section.t(), pos_integer()) ::
          {:ok, Section.t()} | {:error, command_error()}
  def apply_publication_update(%Context{} = context, %Section{} = section, publication_id)
      when is_integer(publication_id),
      do: PublicationUpdates.apply(context, section, publication_id)

  def apply_publication_update(_context, _section, _publication_id),
    do: {:error, :invalid_request}

  @doc """
  Enqueues a job that applies the publication with `publication_id` to `section` with
  `apply_publication_update/3`. The job carries `context`, so its event records the same actor
  with source `:job`, linked to `context`'s operation.
  """
  @spec enqueue_publication_update(Context.t(), Section.t(), pos_integer()) ::
          {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue_publication_update(%Context{} = context, %Section{} = section, publication_id)
      when is_integer(publication_id),
      do: PublicationUpdates.enqueue(context, section, publication_id)

  def enqueue_publication_update(_context, _section, _publication_id),
    do: {:error, :invalid_request}

  @doc """
  Writes the schedule `updates` of section resources of `section` in one statement, under the
  section lock, and records one `curriculum_schedule_changed` per section resource whose
  scheduling type, dates, manual scheduling, or removal from the schedule changed.

  Each update has "id", "scheduling_type", "start_date", "end_date", "manually_scheduled", and
  "removed_from_schedule" (atom or string keys); dates without a time are read in `timezone`
  at the section's preferred scheduling time. Section resources of other sections are not
  written. Section caches are cleared after the commit, also for an empty update, which
  records nothing.

  Returns `{:ok, count}` with the number of rows written, or `{:error,
  :missing_update_parameters}` when an update lacks an attribute.
  """
  @spec update_schedule(Context.t(), Section.t(), [map()], String.t()) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def update_schedule(%Context{} = context, %Section{} = section, updates, timezone)
      when is_list(updates),
      do: Schedule.update(context, section, updates, timezone)

  def update_schedule(_context, _section, _updates, _timezone), do: {:error, :invalid_request}

  @doc """
  Clears the start and end dates (and the removal from the schedule) of every section resource
  of `section` that has a date, under the section lock, and records one
  `curriculum_schedule_changed` per cleared section resource. Returns `{:ok, count}`.
  """
  @spec clear_schedule(Context.t(), Section.t()) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def clear_schedule(%Context{} = context, %Section{} = section),
    do: Schedule.clear(context, section)

  def clear_schedule(_context, _section), do: {:error, :invalid_request}
end
