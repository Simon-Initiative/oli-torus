defmodule Oli.Delivery.Settings.AssessmentSettings do
  import Ecto.Query

  alias Oli.Accounts.Author
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Delivery.Attempts.Core.{ResourceAccess, ResourceAttempt}
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections.Enrollment
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Repo
  alias OliWeb.Common.FormatDateTime

  @supported_keys [
    :start_date,
    :end_date,
    :max_attempts,
    :time_limit,
    :late_policy,
    :late_start,
    :late_submit,
    :scoring_strategy_id,
    :grace_period,
    :retake_mode,
    :assessment_mode,
    :batch_scoring,
    :replacement_strategy,
    :feedback_mode,
    :feedback_scheduled_date,
    :review_submission,
    :password,
    :allow_hints,
    :secure_delivery
  ]

  def supported_keys, do: @supported_keys

  @doc """
  Validates a change of the settings of the assessment with `assessment_setting_id` and
  returns the assessment as the settings page shows it and the section resource fields the
  change writes, without writing anything. `Oli.Delivery.Settings.Audited` writes them.

  `attrs` may use `late_policy` (expanded to `late_start` and `late_submit`); a new start or end
  date moves the other date to keep their distance, and the end date sets the scheduling type.
  Changing secure delivery requires a settings editor of the section (`user`); enabling it
  requires a graded page, while disabling only requires an existing section resource so
  policies can be cleared after their targets become ineligible.

  Options: `:assessments` (the assessments already loaded by the caller), `:ctx` (the session
  context used to read local dates), and `:include_ungraded` (`true` to also accept a page that
  is not a graded assessment, whose section resource is then the current state; used by
  Scenarios to configure practice pages).
  """
  @spec prepare_update(Section.t(), struct(), pos_integer(), map(), map()) ::
          {:ok, map(), map()} | {:error, term()}
  def prepare_update(%Section{} = section, user, assessment_setting_id, attrs, opts \\ %{})
      when is_map(attrs) do
    attrs =
      case Map.fetch(attrs, "secure_delivery") do
        :error -> attrs
        {:ok, value} -> attrs |> Map.delete("secure_delivery") |> Map.put(:secure_delivery, value)
      end

    with :ok <- authorize_secure_change(section, user, assessment_setting_id, attrs),
         {:ok, assessment} <- fetch_assessment(section, assessment_setting_id, opts),
         {:ok, changes} <- normalize_changes(attrs, assessment, Map.get(opts, :ctx)) do
      {:ok, assessment, changes}
    end
  end

  defp authorize_secure_change(section, user, resource_id, attrs) do
    case Map.has_key?(attrs, :secure_delivery) or Map.has_key?(attrs, "secure_delivery") do
      false ->
        :ok

      true ->
        value = Map.get(attrs, :secure_delivery, Map.get(attrs, "secure_delivery"))
        resource = Repo.get_by(SectionResource, section_id: section.id, resource_id: resource_id)

        cond do
          not settings_editor?(section, user) ->
            {:error, :not_authorized}

          value not in [true, false] ->
            {:error, :invalid_secure_delivery}

          value and not Oli.Delivery.SecureAssessments.supported?() ->
            {:error, :secure_delivery_unsupported}

          is_nil(resource) ->
            {:error, :invalid_secure_delivery_target}

          value and (resource.graded != true or resource.resource_type_id != 1) ->
            {:error, :invalid_secure_delivery_target}

          true ->
            :ok
        end
    end
  end

  defp settings_editor?(section, %Author{} = author) do
    Oli.Accounts.is_admin?(author) or
      (section.type == :blueprint and
         Sections.Blueprint.is_author_of_blueprint?(section.slug, author.id))
  end

  defp settings_editor?(section, user) do
    Sections.is_instructor?(user, section.slug) or
      Sections.is_admin?(Oli.Accounts.preload_platform_roles(user), section.slug)
  end

  def get_student_exceptions(section_id) do
    StudentException
    |> where(section_id: ^section_id)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Retrieves all graded assessments (pages) for a given section with their settings and parent container information.

  Each assessment includes:
  - Basic assessment information (name, resource_id, etc.)
  - Combined settings from revision, section resource, and global defaults
  - A formatted display name with container label and numbering (if applicable)
  - Exception count for the assessment

  The display name format:
  - If the assessment's parent is the root container: just the page title
  - If the parent is a non-root container: "<container_label> <numbering_index>: <page title>"
    (e.g., "Unit 1: Introduction to Chemistry" or "Module 2: Quiz")

  Container labels respect customizations from the section (e.g., "Unidad", "Módulo", "Sección")
  and fall back to defaults ("Unit", "Module", "Section") if not customized.

  Uses `Sections.get_parent_containers_map/2` and `Sections.name_with_container_label/3` for
  container relationship lookups and display name formatting.

  ## Parameters
    - `section` - The section struct containing the section to get assessments for
    - `student_exceptions` - A list of student exception records to calculate exception counts

  ## Returns
    A list of assessment maps, each containing:
    - `name` - The original page title
    - `name_with_container_label` - The formatted display name with container context
    - `resource_id` - The resource ID of the assessment
    - `index` - The sequential index of the assessment (not the numbering index)
    - `scheduling_type` - The scheduling type for the assessment
    - `password` - The password for the assessment (if any)
    - `exceptions_count` - The number of student exceptions for this assessment
    - All other fields from `Settings.combine/3`

  ## Examples
      iex> section = Sections.get_section_by_slug("chemistry-101")
      iex> student_exceptions = AssessmentSettings.get_student_exceptions(section.id)
      iex> assessments = AssessmentSettings.get_assessments(section, student_exceptions)
      iex> [first_assessment | _] = assessments
      iex> first_assessment.name
      "Introduction Quiz"
      iex> first_assessment.name_with_container_label
      "Unit 1: Introduction Quiz"
  """
  def get_assessments(%Oli.Delivery.Sections.Section{} = section, student_exceptions) do
    assessments = DeliveryResolver.graded_pages_revisions_and_section_resources(section.slug)

    # Get parent container info for all pages in a single query
    page_ids = Enum.map(assessments, fn {rev, _sr} -> rev.resource_id end)
    parent_containers_map = Sections.get_parent_containers_map(section, page_ids)
    student_started_resource_ids = student_started_resource_ids(section.id, page_ids)
    customizations = section.customizations

    assessments
    |> Enum.with_index()
    |> Enum.map(fn {{rev, sr}, index} ->
      parent_container_info = Map.get(parent_containers_map, rev.resource_id)
      has_student_attempts = MapSet.member?(student_started_resource_ids, rev.resource_id)

      name_with_container_label =
        Sections.name_with_container_label(
          rev.title,
          parent_container_info,
          customizations
        )

      Settings.combine(rev, sr, nil)
      |> Map.from_struct()
      |> Map.merge(%{
        index: index + 1,
        name: rev.title,
        name_with_container_label: name_with_container_label,
        revision_slug: rev.slug,
        is_adaptive: Map.get(rev.content || %{}, "advancedDelivery") == true,
        has_student_attempts: has_student_attempts,
        scheduling_type: sr.scheduling_type,
        password: sr.password,
        exceptions_count:
          Enum.count(student_exceptions, fn se -> se.resource_id == rev.resource_id end)
      })
    end)
  end

  def student_started_resource_ids(_section_id, []), do: MapSet.new()

  def student_started_resource_ids(section_id, resource_ids) when is_list(resource_ids) do
    learner_role_id = ContextRoles.get_role(:context_learner).id

    from(resource_access in ResourceAccess,
      as: :resource_access,
      join: enrollment in Enrollment,
      on:
        enrollment.section_id == resource_access.section_id and
          enrollment.user_id == resource_access.user_id,
      join: enrollment_context_role in "enrollments_context_roles",
      on:
        enrollment_context_role.enrollment_id == enrollment.id and
          enrollment_context_role.context_role_id == ^learner_role_id,
      where:
        resource_access.section_id == ^section_id and
          resource_access.resource_id in ^resource_ids and
          exists(
            from(resource_attempt in ResourceAttempt,
              where: resource_attempt.resource_access_id == parent_as(:resource_access).id
            )
          ),
      distinct: resource_access.resource_id,
      select: resource_access.resource_id
    )
    |> Repo.all()
    |> MapSet.new()
  end

  def student_started?(section_id, resource_id) do
    section_id
    |> student_started_resource_ids([resource_id])
    |> MapSet.member?(resource_id)
  end

  defp fetch_assessment(section, assessment_setting_id, %{} = opts) do
    case {fetch_assessment(section, assessment_setting_id, Map.get(opts, :assessments)),
          Map.get(opts, :include_ungraded, false)} do
      {{:error, {:assessment_not_found, _}}, true} -> fetch_page(section, assessment_setting_id)
      {result, _include_ungraded} -> result
    end
  end

  defp fetch_assessment(section, assessment_setting_id, nil) do
    try do
      {:ok, get_assessment!(section, assessment_setting_id)}
    rescue
      _ -> {:error, {:assessment_not_found, assessment_setting_id}}
    end
  end

  defp fetch_assessment(_section, assessment_setting_id, assessments) when is_list(assessments) do
    case Enum.find(assessments, fn assessment ->
           assessment.resource_id == assessment_setting_id
         end) do
      nil -> {:error, {:assessment_not_found, assessment_setting_id}}
      assessment -> {:ok, assessment}
    end
  end

  defp fetch_page(section, resource_id) do
    case Repo.get_by(SectionResource, section_id: section.id, resource_id: resource_id) do
      nil -> {:error, {:assessment_not_found, resource_id}}
      section_resource -> {:ok, Map.from_struct(section_resource)}
    end
  end

  defp get_assessment!(section, assessment_setting_id) do
    student_exceptions = get_student_exceptions(section.id)

    get_assessments(section, student_exceptions)
    |> Enum.find(fn assessment -> assessment.resource_id == assessment_setting_id end)
    |> case do
      nil -> raise "Assessment not found"
      assessment -> assessment
    end
  end

  @doc """
  Returns the assessment with `assessment_setting_id` as the settings page shows it after
  `changes` were written, or `assessment` with `changes` applied if it can no longer be read.
  """
  @spec refresh_assessment(Section.t(), pos_integer(), map(), map()) :: map()
  def refresh_assessment(section, assessment_setting_id, assessment, changes) do
    case fetch_assessment(section, assessment_setting_id, nil) do
      {:ok, refreshed_assessment} -> refreshed_assessment
      {:error, _} -> Map.merge(assessment, changes)
    end
  end

  defp normalize_changes(attrs, assessment, ctx) do
    attrs =
      attrs
      |> normalize_late_policy()
      |> normalize_dates(assessment, ctx)
      |> normalize_scheduling_type()

    if Map.get(attrs, :feedback_mode) == :scheduled and
         is_nil(Map.get(attrs, :feedback_scheduled_date)) do
      {:error, {:invalid_feedback_schedule, :feedback_scheduled_date_required}}
    else
      {:ok, attrs}
    end
  end

  defp normalize_late_policy(%{late_policy: policy} = attrs) do
    changes =
      case policy do
        :allow_late_start_and_late_submit ->
          %{late_start: :allow, late_submit: :allow}

        :allow_late_submit_but_not_late_start ->
          %{late_start: :disallow, late_submit: :allow}

        :disallow_late_start_and_late_submit ->
          %{late_start: :disallow, late_submit: :disallow}

        _ ->
          %{}
      end

    attrs
    |> Map.delete(:late_policy)
    |> Map.merge(changes)
  end

  defp normalize_late_policy(attrs), do: attrs

  defp normalize_dates(attrs, assessment, nil) do
    attrs
    |> maybe_convert_datetime(:start_date)
    |> maybe_convert_datetime(:end_date)
    |> maybe_convert_datetime(:feedback_scheduled_date)
    |> maybe_preserve_date_distance(assessment)
  end

  defp normalize_dates(attrs, assessment, ctx) do
    attrs
    |> maybe_convert_datetime(:start_date, ctx)
    |> maybe_convert_datetime(:end_date, ctx)
    |> maybe_convert_datetime(:feedback_scheduled_date, ctx)
    |> maybe_preserve_date_distance(assessment)
  end

  defp maybe_convert_datetime(attrs, field), do: maybe_convert_datetime(attrs, field, nil)

  defp maybe_convert_datetime(attrs, field, ctx) do
    case Map.fetch(attrs, field) do
      {:ok, value} when is_binary(value) and value != "" and not is_nil(ctx) ->
        Map.put(attrs, field, FormatDateTime.datestring_to_utc_datetime(value, ctx))

      {:ok, value} when is_binary(value) and value != "" ->
        case DateTime.from_iso8601(value) do
          {:ok, datetime, _offset} -> Map.put(attrs, field, datetime)
          _ -> attrs
        end

      {:ok, ""} ->
        Map.put(attrs, field, nil)

      _ ->
        attrs
    end
  end

  defp maybe_preserve_date_distance(
         %{start_date: _start_date, end_date: _end_date} = attrs,
         _assessment
       ),
       do: attrs

  defp maybe_preserve_date_distance(%{start_date: start_date} = attrs, assessment) do
    {new_start_date, new_end_date, _changed_date_field} =
      OliWeb.Common.Utils.maybe_preserve_dates_distance(:start_date, start_date, assessment)

    attrs
    |> Map.put(:start_date, new_start_date)
    |> Map.put(:end_date, new_end_date)
  end

  defp maybe_preserve_date_distance(%{end_date: end_date} = attrs, assessment) do
    {new_start_date, new_end_date, _changed_date_field} =
      OliWeb.Common.Utils.maybe_preserve_dates_distance(:end_date, end_date, assessment)

    attrs
    |> Map.put(:start_date, new_start_date)
    |> Map.put(:end_date, new_end_date)
  end

  defp maybe_preserve_date_distance(attrs, _assessment), do: attrs

  defp normalize_scheduling_type(%{end_date: end_date} = attrs),
    do: Map.put(attrs, :scheduling_type, if(is_nil(end_date), do: :read_by, else: :due_by))

  defp normalize_scheduling_type(attrs), do: attrs
end
