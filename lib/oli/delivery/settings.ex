defmodule Oli.Delivery.Settings do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Delivery.Settings.Combined
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Attempts.Core.ResourceAttempt

  @doc """
  For a resolved delivery revision of a page and a course section id and user id, return
  the combined settings for that page, section, and user. This is the settings that will
  be used for the user when they are viewing the page. This takes into account any
  instructor customizations for the section, as well as any student exceptions for the
  user.
  """
  def get_combined_settings(%Revision{} = resolved_revision, section_id, user_id) do
    section_resource = Oli.Delivery.Sections.get_section_resource(section_id, resolved_revision.resource_id)
    student_exception = get_student_exception(resolved_revision.resource_id, section_id, user_id)

    combine(resolved_revision, section_resource, student_exception)
  end

  def get_combined_settings(%Revision{} = resolved_revision, section_id) do
    section_resource = Oli.Delivery.Sections.get_section_resource(section_id, resolved_revision.resource_id)

    combine(resolved_revision, section_resource, nil)
  end

  def combine(resolved_revision, section_resource, student_exception) do

    # -1 is a special value that was set by default when this field was added
    # to the section_resources schema which allows us to pull through the
    # current revision max_attempts, until the section_resource is updated via
    # actual instructor customization
    max_attempts = case combine_field(:max_attempts, section_resource, student_exception) do
      -1 -> resolved_revision.max_attempts
      value -> value
    end

    explanation_strategy = case combine_field(:explanation_strategy, section_resource, student_exception) do
      nil -> resolved_revision.explanation_strategy
      v -> v
    end

    collab_space_config = case combine_field(:collab_space_config, section_resource, student_exception) do
      nil -> resolved_revision.collab_space_config
      v -> v
    end

    %Combined{
      end_date: combine_field(:end_date, section_resource, student_exception),
      max_attempts: max_attempts,
      retake_mode: combine_field(:retake_mode, section_resource, student_exception),
      late_submit: combine_field(:late_submit, section_resource, student_exception),
      late_start: combine_field(:late_start, section_resource, student_exception),
      time_limit: combine_field(:time_limit, section_resource, student_exception),
      grace_period: combine_field(:grace_period, section_resource, student_exception),
      scoring_strategy_id: combine_field(:scoring_strategy_id, section_resource, student_exception),
      review_submission: combine_field(:review_submission, section_resource, student_exception),
      feedback_mode: combine_field(:feedback_mode, section_resource, student_exception),
      feedback_scheduled_date: combine_field(:feedback_scheduled_date, section_resource, student_exception),
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

  def was_late?(%ResourceAttempt{} = resource_attempt, %Combined{} = effective_settings, now) do
    now > determine_effective_deadline(resource_attempt, effective_settings)
  end

  @doc """
  Determine if a new attempt is allowed to be started.
  """
  def new_attempt_allowed(%Combined{} = effective_settings, num_attempts_taken, blocking_gates) do

    with {:allowed} <- check_blocking_gates(blocking_gates),
      {:allowed} <- check_num_attempts(effective_settings, num_attempts_taken),
      {:allowed} <- check_end_date(effective_settings)
    do
      {:allowed}
    else
      reason -> reason
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

  defp check_end_date(%Combined{end_date: nil}), do: {:allowed}
  defp check_end_date(%Combined{end_date: end_date} = effective_settings) do

    effective_end_date = DateTime.add(end_date, effective_settings.grace_period, :minute)
    if (DateTime.compare(effective_end_date, DateTime.utc_now()) == :gt or effective_settings.late_start == :allow) do
      {:allowed}
    else
      {:end_date_passed}
    end
  end

  def determine_effective_deadline(%ResourceAttempt{} = resource_attempt, %Combined{} = effective_settings) do
    case {effective_settings.end_date, effective_settings.time_limit} do

      # no end date or time limit, no deadline
      {nil, nil} -> nil

      # only a time limit, just add the minutes to the start
      {nil, time_limit} -> DateTime.add(resource_attempt.inserted_at, time_limit, :minute)

      # only an end date, use that
      {end_date, 0} -> end_date

      # both an end date and a time limit, use the earlier of the two
      {end_date, time_limit} ->
        if end_date < DateTime.add(resource_attempt.inserted_at, time_limit, :minute) do
          end_date
        else
          DateTime.add(resource_attempt.inserted_at, time_limit, :minute)
        end
    end
    |> DateTime.add(effective_settings.grace_period, :minute)
  end

end
