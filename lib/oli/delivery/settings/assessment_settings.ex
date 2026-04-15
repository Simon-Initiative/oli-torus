defmodule Oli.Delivery.Settings.AssessmentSettings do
  import Ecto.Query

  alias Ecto.Multi
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.AutoSubmitCustodian
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Delivery.Sections.SectionResourceDepot
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
    :allow_hints
  ]

  def supported_keys, do: @supported_keys

  def update(%Section{} = section, user, assessment_setting_id, attrs, opts \\ %{})
      when is_map(attrs) do
    assessments = Map.get(opts, :assessments)
    ctx = Map.get(opts, :ctx)

    with {:ok, assessment} <- fetch_assessment(section, assessment_setting_id, assessments),
         {:ok, changes} <- normalize_changes(attrs, assessment, ctx),
         setting_changes <- build_settings_changes(changes, assessment, section.id, user),
         {:ok, _result} <- persist_update(section, assessment, changes, setting_changes) do
      {:ok,
       %{
         assessment: refresh_assessment(section, assessment_setting_id, assessment, changes),
         applied_changes: changes
       }}
    end
  end

  def do_update(:late_policy, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    update(section, user, asmt_set_id, %{late_policy: new_value}, %{assessments: asmts})
    |> normalize_update_result()
  end

  def do_update(key, asmt_set_id, new_value, resources) do
    %{section: section, user: user, assessments: asmts} = resources

    update(section, user, asmt_set_id, %{key => new_value}, %{assessments: asmts})
    |> normalize_update_result()
  end

  defp normalize_update_result({:ok, result}), do: {:ok, result}
  defp normalize_update_result({:error, reason}), do: reason

  defp updated_section_resource_depot(multi) do
    Multi.run(multi, :updated_section_resource_depot, fn
      _repo, %{update_section_resource: section_resource} ->
        {:ok, SectionResourceDepot.update_section_resource(section_resource)}
    end)
  end

  defp get_section_resource(multi, section_id, assessment_setting_id) do
    Multi.run(multi, :get_section_resource, fn _repo, _changes ->
      with section_resource = %SectionResource{} <-
             SectionResourceDepot.get_section_resource(section_id, assessment_setting_id) do
        {:ok, section_resource}
      else
        _nil ->
          {:error, "Could not find section resource"}
      end
    end)
  end

  defp update_section_resource(%Multi{} = multi, changes, section_id, asmt_set_id) do
    Multi.update(multi, :update_section_resource, fn %{get_section_resource: section_resource} ->
      case changes do
        %{late_submit: :allow} -> AutoSubmitCustodian.cancel(section_id, asmt_set_id, nil)
        _others -> nil
      end

      SectionResource.changeset(section_resource, changes)
    end)
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
    parent_containers_map = Sections.get_parent_containers_map(section.id, page_ids)
    customizations = section.customizations

    assessments
    |> Enum.with_index()
    |> Enum.map(fn {{rev, sr}, index} ->
      parent_container_info = Map.get(parent_containers_map, rev.resource_id)

      name_with_container_label =
        Sections.name_with_container_label(
          rev.title,
          parent_container_info,
          customizations
        )

      Settings.combine(rev, sr, nil)
      |> Map.merge(%{
        index: index + 1,
        name: rev.title,
        name_with_container_label: name_with_container_label,
        scheduling_type: sr.scheduling_type,
        password: sr.password,
        exceptions_count:
          Enum.count(student_exceptions, fn se -> se.resource_id == rev.resource_id end)
      })
    end)
  end

  defp get_user_type(%Author{} = _), do: :author
  defp get_user_type(_), do: :instructor

  defp persist_update(section, assessment, changes, setting_changes) do
    assessment_setting_id = assessment.resource_id

    multi =
      Multi.new()
      |> get_section_resource(section.id, assessment_setting_id)
      |> update_section_resource(changes, section.id, assessment_setting_id)
      |> maybe_adjust_auto_submit_after_update(section.id, assessment, changes)
      |> insert_settings_changes(setting_changes)
      |> updated_section_resource_depot()

    case Repo.transaction(multi) do
      {:ok, result} -> {:ok, result}
      {:error, :update_section_resource, _, _} = error -> error
      {:error, :get_section_resource, _, _} = error -> error
      {:error, :settings_changes, _, _} = error -> error
      {:error, :adjust_auto_submit_after_update, _, _} = error -> error
    end
  end

  defp maybe_adjust_auto_submit_after_update(
         %Multi{} = multi,
         section_id,
         assessment,
         %{end_date: new_end_date}
       ) do
    Multi.run(multi, :adjust_auto_submit_after_update, fn _repo, _changes ->
      if assessment.late_submit == :disallow and not is_nil(assessment.end_date) do
        case AutoSubmitCustodian.adjust(
               section_id,
               assessment.resource_id,
               assessment.end_date,
               new_end_date,
               nil
             ) do
          {:ok, count} -> {:ok, count}
          error -> error
        end
      else
        {:ok, 0}
      end
    end)
  end

  defp maybe_adjust_auto_submit_after_update(
         %Multi{} = multi,
         _section_id,
         _assessment,
         _changes
       ),
       do: multi

  defp insert_settings_changes(%Multi{} = multi, []), do: multi

  defp insert_settings_changes(%Multi{} = multi, setting_changes) do
    Multi.run(multi, :settings_changes, fn _repo, _changes ->
      case Settings.bulk_insert_settings_changes(setting_changes) do
        {_count, _rows} = result -> {:ok, result}
        error -> error
      end
    end)
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

  defp get_assessment!(section, assessment_setting_id) do
    student_exceptions = get_student_exceptions(section.id)

    get_assessments(section, student_exceptions)
    |> Enum.find(fn assessment -> assessment.resource_id == assessment_setting_id end)
    |> case do
      nil -> raise "Assessment not found"
      assessment -> assessment
    end
  end

  defp refresh_assessment(section, assessment_setting_id, assessment, changes) do
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

  defp build_settings_changes(attrs, assessment) do
    Enum.map(attrs, fn {key, value} ->
      %{
        key: key,
        new_value: value,
        old_value: Map.get(assessment, key)
      }
    end)
  end

  defp insert_setting_changes_payload(setting_changes, section_id, user) do
    date = DateTime.utc_now() |> DateTime.truncate(:second)

    Enum.map(setting_changes, fn %{key: key, new_value: new_value, old_value: old_value} ->
      %{
        resource_id: nil,
        section_id: section_id,
        user_id: user.id,
        user_type: get_user_type(user),
        key: Atom.to_string(key),
        new_value: stringify_setting_value(new_value),
        old_value: stringify_setting_value(old_value),
        inserted_at: date,
        updated_at: date
      }
    end)
  end

  defp build_settings_changes(attrs, assessment, section_id, user) do
    attrs
    |> build_settings_changes(assessment)
    |> insert_setting_changes_payload(section_id, user)
    |> Enum.map(fn payload -> Map.put(payload, :resource_id, assessment.resource_id) end)
  end

  defp stringify_setting_value(nil), do: nil
  defp stringify_setting_value(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp stringify_setting_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_setting_value(value), do: "#{value}"
end
