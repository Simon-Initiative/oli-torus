defmodule Oli.Delivery.Settings do

  import Ecto.Query, warn: false
  alias Oli.Repo
  alias Oli.Resources.Revision
  alias Oli.Delivery.Settings.Combined
  alias Oli.Delivery.Settings.StudentException

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

  defp combine(resolved_revision, section_resource, student_exception) do

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
  defp combine_field(field, section_resource, student_exception) do
    case student_exception do
      nil -> Map.get(section_resource, field)
      _ -> case Map.get(student_exception, field) do
        nil -> Map.get(section_resource, field)
        v -> v
      end
    end
  end

  def get_student_exception(resource_id, section_id, user_id) do
    StudentException
    |> where(resource_id: ^resource_id)
    |> where(section_id: ^section_id)
    |> where(user_id: ^user_id)
    |> Repo.one()
  end

end
