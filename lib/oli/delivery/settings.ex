defmodule Oli.Delivery.Settings do
  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Delivery.Settings.Combined
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Settings.SettingsChanges
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Publishing.DeliveryResolver

  @doc """
  For a resolved delivery revision of a page and a course section id and user id, return
  the combined settings for that page, section, and user. This is the settings that will
  be used for the user when they are viewing the page. This takes into account any
  instructor customizations for the section, as well as any student exceptions for the
  user.
  """
  def get_combined_settings(%Revision{} = resolved_revision, section_id, user_id) do
    section_resource =
      Oli.Delivery.Sections.get_section_resource(section_id, resolved_revision.resource_id)

    student_exception = get_student_exception(resolved_revision.resource_id, section_id, user_id)

    combine(resolved_revision, section_resource, student_exception)
  end

  def get_combined_settings(%Revision{} = resolved_revision, section_id) do
    section_resource =
      Oli.Delivery.Sections.get_section_resource(section_id, resolved_revision.resource_id)

    combine(resolved_revision, section_resource, nil)
  end

  @doc """
  For a ResourceAttempt, return the combined settings for that page, section, and user. This is the settings that will
  be used for the user when they are viewing the page. This takes into account any
  instructor customizations for the section, as well as any student exceptions for the
  user.
  """
  def get_combined_settings(%ResourceAttempt{} = resource_attempt) do
    %{revision: resolved_revision, resource_access: %{user_id: user_id, section_id: section_id}} =
      Repo.preload(resource_attempt, [:revision, :resource_access])

    section_resource =
      Oli.Delivery.Sections.get_section_resource(section_id, resolved_revision.resource_id)

    student_exception = get_student_exception(resolved_revision.resource_id, section_id, user_id)

    combine(resolved_revision, section_resource, student_exception)
  end

  def get_combined_settings_for_all_resources(section_id, user_id, resource_ids \\ nil) do
    section = Oli.Delivery.Sections.get_section!(section_id)

    student_exceptions_map =
      get_all_student_exceptions(section_id, user_id, resource_ids)
      |> Enum.reduce(%{}, fn se, acc -> Map.put(acc, se.resource_id, se) end)

    get_page_resources_with_settings(section.slug, resource_ids)
    |> Enum.reduce(%{}, fn {resource_id, section_resource, page_settings}, acc ->
      student_exception = student_exceptions_map[resource_id]

      Map.put(acc, resource_id, combine(page_settings, section_resource, student_exception))
    end)
  end

  @doc """
  For a course section id and user id, return a map of resource_id to student exception settings.
  The third argument allows to specific the field/s to be returned in the map.
  If no fields are specified, all fields from the Oli.Delivery.Settings.Combined struct are returned.

  If the are no student exception for a specific resource id, that resource id won't be included in the map.
  (so if there are no student exceptions for any resources, an empty map will be returned)

  Example:

  ```
  iex> Oli.Delivery.Settings.get_student_exception_setting_for_all_resources(1, 2)
  %{
  22433 => %{
    max_attempts: nil,
    password: nil,
    end_date: ~U[2024-05-25 13:41:00Z],
    time_limit: 30,
    collab_space_config: nil,
    start_date: nil,
    resource_id: 22433,
    retake_mode: nil,
    assessment_mode: nil,
    late_submit: nil,
    late_start: nil,
    grace_period: nil,
    scoring_strategy_id: nil,
    review_submission: nil,
    feedback_mode: nil,
    feedback_scheduled_date: nil,
    explanation_strategy: nil
  }
  }

  iex> Oli.Delivery.Settings.get_student_exception_setting_for_all_resources(1, 2, [:end_date, :time_limit])
  %{22433 => %{end_date: ~U[2024-05-25 13:41:00Z], time_limit: 30}}

  iex> Oli.Delivery.Settings.get_student_exception_setting_for_all_resources(1, 5)
  %{}
  """

  def get_student_exception_setting_for_all_resources(section_id, user_id, fields \\ nil)

  def get_student_exception_setting_for_all_resources(section_id, user_id, nil) do
    fields = %Oli.Delivery.Settings.StudentException{} |> Map.from_struct() |> Map.keys()

    get_all_student_exceptions(section_id, user_id)
    |> Enum.reduce(%{}, fn se, acc -> Map.put(acc, se.resource_id, Map.take(se, fields)) end)
  end

  def get_student_exception_setting_for_all_resources(section_id, user_id, fields)
      when is_list(fields) do
    get_all_student_exceptions(section_id, user_id)
    |> Enum.reduce(%{}, fn se, acc -> Map.put(acc, se.resource_id, Map.take(se, fields)) end)
  end

  defp get_page_resources_with_settings(section_slug, resource_ids) do
    page_id = Oli.Resources.ResourceType.id_for_page()

    resource_ids_filter =
      case resource_ids do
        nil -> true
        ids -> dynamic([rev: rev], rev.resource_id in ^ids)
      end

    from([s: s, sr: sr, rev: rev] in DeliveryResolver.section_resource_revisions(section_slug),
      where: rev.resource_type_id == ^page_id,
      select: {
        rev.resource_id,
        sr,
        %{
          resource_id: rev.resource_id,
          max_attempts: rev.max_attempts,
          explanation_strategy: rev.explanation_strategy,
          collab_space_config: rev.collab_space_config
        }
      }
    )
    |> where(^resource_ids_filter)
    |> Repo.all()
  end

  def combine(resolved_revision, section_resource, student_exception) do
    # -1 is a special value that was set by default when this field was added
    # to the section_resources schema which allows us to pull through the
    # current revision max_attempts, until the section_resource is updated via
    # actual instructor customization
    max_attempts =
      case combine_field(:max_attempts, section_resource, student_exception) do
        -1 -> resolved_revision.max_attempts
        value -> value
      end

    explanation_strategy =
      case combine_field(:explanation_strategy, section_resource, student_exception) do
        nil -> resolved_revision.explanation_strategy
        v -> v
      end

    collab_space_config =
      case combine_field(:collab_space_config, section_resource, student_exception) do
        nil -> resolved_revision.collab_space_config
        v -> v
      end

    %Combined{
      resource_id: resolved_revision.resource_id,
      scheduling_type: section_resource.scheduling_type,
      start_date: combine_field(:start_date, section_resource, student_exception),
      end_date: combine_field(:end_date, section_resource, student_exception),
      max_attempts: max_attempts,
      retake_mode: combine_field(:retake_mode, section_resource, student_exception),
      assessment_mode: combine_field(:assessment_mode, section_resource, student_exception),
      late_submit: combine_field(:late_submit, section_resource, student_exception),
      late_start: combine_field(:late_start, section_resource, student_exception),
      time_limit: combine_field(:time_limit, section_resource, student_exception),
      grace_period: combine_field(:grace_period, section_resource, student_exception),
      password: combine_field(:password, section_resource, student_exception),
      scoring_strategy_id:
        combine_field(:scoring_strategy_id, section_resource, student_exception),
      review_submission: combine_field(:review_submission, section_resource, student_exception),
      feedback_mode: combine_field(:feedback_mode, section_resource, student_exception),
      feedback_scheduled_date:
        combine_field(:feedback_scheduled_date, section_resource, student_exception),
      collab_space_config: collab_space_config,
      explanation_strategy: explanation_strategy
    }
  end

  # This combines the settings found in the section resource with the settings
  # found in the student exception, giving precedence to the student exception when
  # there is a setting defined there.
  defp combine_field(field, section_resource, nil), do: Map.get(section_resource, field)

  defp combine_field(field, section_resource, student_exception) do
    case Map.get(student_exception, field) do
      nil -> Map.get(section_resource, field)
      v -> v
    end
  end

  def get_student_exception(resource_id, section_id, user_id) do
    StudentException
    |> where(resource_id: ^resource_id)
    |> where(section_id: ^section_id)
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

  def get_all_student_exceptions(section_id, user_id, resource_ids \\ nil) do
    resource_ids_filter =
      case resource_ids do
        nil -> true
        ids -> dynamic([se], se.resource_id in ^ids)
      end

    StudentException
    |> where(section_id: ^section_id)
    |> where(user_id: ^user_id)
    |> where(^resource_ids_filter)
    |> Repo.all()
  end

  def update_student_exception(
        %StudentException{} = student_exception,
        attrs,
        required_fields \\ []
      ) do
    StudentException.changeset(student_exception, attrs, required_fields)
    |> Repo.update()
  end

  def was_late?(_, %Combined{late_submit: :disallow}, _now), do: false

  def was_late?(
        %ResourceAttempt{} = resource_attempt,
        %Combined{late_submit: :allow} = effective_settings,
        now
      ) do
    case determine_effective_deadline(resource_attempt, effective_settings) do
      nil -> false
      effective_deadline -> DateTime.compare(now, effective_deadline) == :gt
    end
  end

  @doc """
  Determine if a new attempt is allowed to be started.
  """
  def new_attempt_allowed(%Combined{} = effective_settings, num_attempts_taken, blocking_gates) do
    with {:allowed} <- check_blocking_gates(blocking_gates),
         {:allowed} <- check_num_attempts(effective_settings, num_attempts_taken),
         {:allowed} <- check_start_date(effective_settings),
         {:allowed} <- check_end_date(effective_settings) do
      {:allowed}
    end
  end

  defp check_blocking_gates([]), do: {:allowed}
  defp check_blocking_gates(_), do: {:blocking_gates}

  defp check_num_attempts(settings, num_attempts_taken) do
    if max(settings.max_attempts - num_attempts_taken, 0) > 0 or settings.max_attempts == 0 do
      {:allowed}
    else
      {:no_attempts_remaining}
    end
  end

  def check_start_date(%Combined{start_date: nil}), do: {:allowed}

  def check_start_date(%Combined{start_date: start_date}) do
    if DateTime.compare(start_date, DateTime.utc_now()) == :gt,
      do: {:before_start_date},
      else: {:allowed}
  end

  def check_end_date(%Combined{end_date: nil}), do: {:allowed}

  def check_end_date(%Combined{end_date: end_date} = effective_settings) do
    effective_end_date = DateTime.add(end_date, effective_settings.grace_period, :minute)

    cond do
      DateTime.compare(effective_end_date, DateTime.utc_now()) == :gt ->
        {:allowed}

      effective_settings.late_start == :allow ->
        {:allowed}

      effective_settings.scheduling_type == :read_by ->
        {:allowed}

      true ->
        {:end_date_passed}
    end
  end

  def determine_effective_deadline(nil, _), do: nil

  def determine_effective_deadline(
        %ResourceAttempt{} = resource_attempt,
        %Combined{} = effective_settings
      ) do
    deadline =
      case {effective_settings.end_date, effective_settings.time_limit} do
        # no end date or time limit, no deadline
        {nil, nil} ->
          nil

        {nil, 0} ->
          nil

        # only a time limit, just add the minutes to the start
        {nil, time_limit} ->
          DateTime.add(resource_attempt.inserted_at, time_limit, :minute)

        # only an end date, use that
        {end_date, 0} ->
          end_date

        # both an end date and a time limit, use the earlier of the two
        {end_date, time_limit} ->
          if end_date < DateTime.add(resource_attempt.inserted_at, time_limit, :minute),
            do: end_date,
            else: DateTime.add(resource_attempt.inserted_at, time_limit, :minute)
      end

    case deadline do
      nil -> nil
      deadline -> DateTime.add(deadline, effective_settings.grace_period, :minute)
    end
  end

  def show_feedback?(%Combined{feedback_mode: :allow}), do: true
  def show_feedback?(%Combined{feedback_mode: :disallow}), do: false

  def show_feedback?(%Combined{feedback_scheduled_date: date}) do
    DateTime.compare(date, DateTime.utc_now()) == :lt
  end

  def show_feedback?(nil), do: true

  def check_password(_effective_settings, ""), do: {:empty_password}
  def check_password(_effective_settings, nil), do: {:allowed}

  def check_password(%Combined{password: password}, password),
    do: {:allowed}

  def check_password(_, _), do: {:invalid_password}

  @doc """
  Insert a new settings change record.
  """
  @spec insert_settings_change(map()) :: {:ok, SettingsChanges.t()} | {:error, Ecto.Changeset.t()}
  def insert_settings_change(attrs) do
    SettingsChanges.changeset(
      %SettingsChanges{},
      attrs
    )
    |> Repo.insert()
  end

  @doc """
  Insert multiple settings change records.
  """
  @spec bulk_insert_settings_changes([map()]) ::
          {:ok, [SettingsChanges.t()]} | {:error, Ecto.Changeset.t()}
  def bulk_insert_settings_changes(settings_changes) do
    Repo.insert_all(SettingsChanges, settings_changes)
  end

  @doc """
  Fetch all settings changes.
  """
  @spec fetch_all_settings_changes() :: [SettingsChanges.t()]
  def fetch_all_settings_changes(),
    do:
      SettingsChanges
      |> Repo.all()
end
