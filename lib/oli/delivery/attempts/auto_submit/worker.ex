defmodule Oli.Delivery.Attempts.AutoSubmit.Worker do
  use Oban.Worker, queue: :auto_submit, max_attempts: 5

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Attempts.PageLifecycle.{FinalizationSummary, FinalizationContext}
  alias Oli.Delivery.Settings
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.PageLifecycle.Graded

  require Logger

  @moduledoc """
  An Oban worker driven page attempts auto submission creator.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "attempt_guid" => resource_attempt_guid,
          "section_slug" => section_slug,
          "datashop_session_id" => datashop_session_id
        }
      }) do
    Oli.Repo.transaction(fn _ ->
      case Oli.Delivery.Attempts.Core.get_resource_attempt_by(attempt_guid: resource_attempt_guid) do
        nil ->
          Oli.Repo.rollback({:not_found})

        resource_attempt ->
          resource_access = Oli.Repo.get(ResourceAccess, resource_attempt.resource_access_id)

          context = %FinalizationContext{
            resource_attempt: resource_attempt,
            section_slug: section_slug,
            datashop_session_id: datashop_session_id,
            effective_settings:
              Oli.Delivery.Settings.get_combined_settings(
                resource_attempt.revision,
                resource_access.section_id,
                resource_access.user_id
              )
          }

          Logger.info(
            "Auto submit: got resource attempt for guid #{resource_attempt_guid} and section slug #{section_slug}"
          )

          case Graded.finalize(context) do
            {:ok,
             %FinalizationSummary{
               resource_access: resource_access,
               part_attempt_guids: part_attempt_guids,
               lifecycle_state: :evaluated
             }} ->
              Logger.info(
                "Auto submit: finalized as :evaluated for guid #{resource_attempt_guid} and section slug #{section_slug}"
              )

              section = Sections.get_section_by(slug: section_slug)
              user = Oli.Accounts.get_user!(resource_access.user_id)

              Oli.Delivery.Snapshots.Worker.perform_now(part_attempt_guids, section_slug)

              Logger.info(
                "Auto submit: snapshots created for guid #{resource_attempt_guid} and section slug #{section_slug}"
              )

              if section.grade_passback_enabled do
                Logger.info(
                  "Auto submit: gradepassback STARTED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                result =
                  Oli.Grading.send_score_to_lms(
                    section,
                    user,
                    resource_access,
                    Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.access_token_provider(
                      section
                    )
                  )

                Logger.info(
                  "Auto submit: gradepassback FINISHED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                result
              else
                Logger.info(
                  "Auto submit: gradepassback NOT ENABLED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                :ok
              end

            {:ok, _} ->
              Logger.info(
                "Auto submit: finalized not as :evaluated for guid #{resource_attempt_guid} and section slug #{section_slug}"
              )

              :ok

            {:error, :already_submitted} ->
              Logger.info(
                "Auto submit: was already finalized for guid #{resource_attempt_guid} and section slug #{section_slug}"
              )

              section = Sections.get_section_by(slug: section_slug)
              user = Oli.Accounts.get_user!(resource_access.user_id)

              if section.grade_passback_enabled do
                Logger.info(
                  "Auto submit: gradepassback STARTED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                result =
                  Oli.Grading.send_score_to_lms(
                    section,
                    user,
                    resource_access,
                    Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.access_token_provider(
                      section
                    )
                  )

                Logger.info(
                  "Auto submit: gradepassback FINISHED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                result
              else
                Logger.info(
                  "Auto submit: gradepassback NOT ENABLED for guid #{resource_attempt_guid} and section slug #{section_slug}"
                )

                :ok
              end

            {:error, error} ->
              Logger.info(
                "Auto submit: error #{inspect(error)} during finalization for guid #{resource_attempt_guid} and section slug #{section_slug}"
              )

              Oli.Repo.rollback(error)
          end
      end
    end)
  end

  @doc """
  Possibly schedules a finalization auto submit for a resource attempt. If the resource attempt
  is not eligible for auto submit, then no job is scheduled. If the resource attempt is eligible
  for auto submit, then a job is scheduled for the deadline and {:ok, job} is returned. If the
  resource attempt is already past the deadline or if there is no deadline or late_submit == :allow
  then {:ok, :not_scheduled} is returned.
  """
  def maybe_schedule_auto_submit(
        effective_settings,
        section_slug,
        resource_attempt,
        datashop_session_id
      ) do
    if needs_job?(effective_settings) do
      # calculate the deadline, taking into account the grace period
      deadline = Settings.determine_effective_deadline(resource_attempt, effective_settings)

      # ensure that we only schedule for deadlines in the future
      if DateTime.compare(deadline, DateTime.utc_now()) == :lt do
        {:ok, :not_scheduled}
      else
        # we schedule the auto submit job 1 minute past the actual deadline to allow for a client side
        # auto submit to take place and cancel this job.
        deadline_with_slack = add_slack(deadline)

        {:ok, job} =
          %{
            attempt_guid: resource_attempt.attempt_guid,
            section_slug: section_slug,
            datashop_session_id: datashop_session_id
          }
          |> Worker.new(scheduled_at: deadline_with_slack)
          |> Oban.insert()

        {:ok, job.id}
      end
    else
      {:ok, :not_scheduled}
    end
  end

  def add_slack(deadline) do
    DateTime.add(deadline, 1, :minute)
  end

  def cancel_auto_submit(%ResourceAttempt{auto_submit_job_id: id}), do: Oban.cancel_job(id)

  # We only need an auto submit job when there is a deadline and the late_submit policy
  # is :disallow. If the late_submit policy is :allow, then we don't need to schedule.
  defp needs_job?(es) do
    has_deadline?(es) and es.late_submit == :disallow
  end

  defp has_deadline?(effective_settings) do
    has_due_by_deadline =
      effective_settings.scheduling_type == :due_by and not is_nil(effective_settings.end_date)

    has_due_by_deadline or effective_settings.time_limit > 0
  end
end
