defmodule Oli.Delivery.Settings.Audited do
  @moduledoc """
  Application boundary for audited changes to assessment settings: the section-level settings
  of each assessment and the per-student exceptions that override them.

  Each command writes its change and its events in one transaction, so a change is never
  committed without its events and a failed or rolled-back change records nothing. An
  assessment change records `assessment_settings_changed` with the persisted fields that
  changed (a new date that moves the other date, or a late policy that sets `late_start` and
  `late_submit`, appear in the same event); exceptions record `student_exception_created`,
  `student_exception_updated`, and `student_exception_deleted` with the student as the affected
  user. Passwords are recorded only as a redaction marker. A save that changes nothing records
  nothing.

  Commands do not authorize the actor: callers keep their existing authorization, and the
  secure-delivery editor check that lived in the moved update still runs, for the account the
  context names. The writes live in private modules under this namespace, so this module is the
  only way to make them.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Oli.Auditing.Context
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Settings.Audited.{AssessmentSettings, StudentExceptions}
  alias Oli.Delivery.Settings.StudentException

  @type command_error ::
          :invalid_request
          | :not_found
          | :nested_transaction
          | Ecto.Changeset.t()
          | Oli.Auditing.Error.t()
          | term()

  @doc """
  Changes the settings of the assessment with `resource_id` in `section` and records
  `assessment_settings_changed` with the fields that changed.

  `attrs` and `opts` are those of `Oli.Delivery.Settings.AssessmentSettings.prepare_update/5`,
  which validates the change; the secure-delivery check runs for the account `context` names.
  The scheduled auto-submits are adjusted in the same transaction, and the cached section
  resource is refreshed after commit.

  Returns the assessment as the settings page shows it and the fields written
  (`%{assessment: map(), applied_changes: map()}`). A missing section resource returns
  `:not_found`.
  """
  @spec update_assessment_settings(Context.t(), Section.t(), pos_integer(), map(), map()) ::
          {:ok, %{assessment: map(), applied_changes: map()}} | {:error, command_error()}
  def update_assessment_settings(context, section, resource_id, attrs, opts \\ %{})

  def update_assessment_settings(
        %Context{} = context,
        %Section{} = section,
        resource_id,
        attrs,
        opts
      )
      when is_integer(resource_id) and is_map(attrs) and is_map(opts),
      do: AssessmentSettings.update(context, section, resource_id, attrs, opts)

  def update_assessment_settings(_context, _section, _resource_id, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Copies the settings of the assessment with `base_resource_id` to the other graded pages of
  `section`, as the settings table's bulk apply does: the common settings to every page, the
  replacement strategy to the non-adaptive ones, and the scoring mode to the non-adaptive ones
  no student has started. Records one `assessment_settings_changed` per assessment that
  changed and returns how many changed. Scheduled auto-submits are not adjusted.
  """
  @spec bulk_apply_assessment_settings(Context.t(), Section.t(), pos_integer()) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def bulk_apply_assessment_settings(%Context{} = context, %Section{} = section, base_resource_id)
      when is_integer(base_resource_id),
      do: AssessmentSettings.bulk_apply(context, section, base_resource_id)

  def bulk_apply_assessment_settings(_context, _section, _base_resource_id),
    do: {:error, :invalid_request}

  @doc """
  Creates the exception of the student with `user_id` for the assessment with `resource_id`, or
  updates the existing one, with `attrs` (atom or string keys; `late_policy` and the
  `due_date` alias of `end_date` are accepted). Records `student_exception_created`, with the
  overrides set (none for an exception created empty), or `student_exception_updated` with the
  fields that changed. An update maintains the student's scheduled auto-submit in the same
  transaction.

  Options: `:required` lists fields that must have a value.
  """
  @spec set_student_exception(
          Context.t(),
          Section.t(),
          pos_integer(),
          pos_integer(),
          map(),
          keyword()
        ) :: {:ok, StudentException.t()} | {:error, command_error()}
  def set_student_exception(context, section, resource_id, user_id, attrs \\ %{}, opts \\ [])

  def set_student_exception(
        %Context{} = context,
        %Section{} = section,
        resource_id,
        user_id,
        attrs,
        opts
      )
      when is_integer(resource_id) and is_integer(user_id) and is_map(attrs) and is_list(opts),
      do: StudentExceptions.set(context, section, resource_id, user_id, attrs, opts)

  def set_student_exception(_context, _section, _resource_id, _user_id, _attrs, _opts),
    do: {:error, :invalid_request}

  @doc """
  Removes the exceptions of the students with `user_ids` for the assessment with
  `resource_id` and records one `student_exception_deleted` per removed exception. Students
  without an exception are skipped. Returns how many were removed.
  """
  @spec remove_student_exceptions(Context.t(), Section.t(), pos_integer(), [pos_integer()]) ::
          {:ok, non_neg_integer()} | {:error, command_error()}
  def remove_student_exceptions(%Context{} = context, %Section{} = section, resource_id, user_ids)
      when is_integer(resource_id) and is_list(user_ids),
      do: StudentExceptions.remove(context, section, resource_id, user_ids)

  def remove_student_exceptions(_context, _section, _resource_id, _user_ids),
    do: {:error, :invalid_request}
end
