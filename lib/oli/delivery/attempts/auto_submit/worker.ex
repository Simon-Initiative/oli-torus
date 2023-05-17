defmodule Oli.Delivery.Attempts.AutoSubmit.Worker do
  use Oban.Worker, queue: :auto_submit, max_attempts: 5

  alias Oli.Delivery.Attempts.AutoSubmit.Worker
  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Attempts.Core.ResourceAttempt
  alias Oli.Delivery.Settings

  @moduledoc """
  An Oban worker driven page attempts auto submission creator.
  """

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"attempt_guid" => attempt_guid, "section_slug" => section_slug, "datashop_session_id" => datashop_session_id}
      }) do
    PageLifecycle.finalize(section_slug, attempt_guid, datashop_session_id)
  end

  @doc """
  Possibly schedules a finalization auto submit for a resource attempt. If the resource attempt
  is not eligible for auto submit, then no job is scheduled. If the resource attempt is eligible
  for auto submit, then a job is scheduled for the deadline and {:ok, job} is returned. If the
  resource attempt is already past the deadline or if there is no deadline or late_submit == :allow
  then {:ok, :not_scheduled} is returned.
  """
  def maybe_schedule_auto_submit(effective_settings, section_slug, resource_attempt, datashop_session_id) do

    if needs_job?(effective_settings) do
      # calculate the deadline, taking into account the grace period
      deadline = Settings.determine_effective_deadline(resource_attempt, effective_settings)

      # ensure that we only schedule for deadlines in the future
      if DateTime.compare(deadline, DateTime.utc_now()) == :lt do
        {:ok, :not_scheduled}
      else

        # we schedule the auto submit job 1 minute past the actual deadline to allow for a client side
        # auto submit to take place and cancel this job.
        deadline_with_slack = DateTime.add(deadline, 1, :minute)

        {:ok, job} = %{attempt_guid: resource_attempt.attempt_guid, section_slug: section_slug, datashop_session_id: datashop_session_id}
        |> Worker.new(scheduled_at: deadline_with_slack)
        |> Oban.insert()

        {:ok, job.id}
      end

    else
      {:ok, :not_scheduled}
    end

  end

  def cancel_auto_submit(%ResourceAttempt{auto_submit_job_id: id}), do: Oban.cancel_job(id)

  # We only need an auto submit job when there is a deadline and the late_submit policy
  # is :disallow. If the late_submit policy is :allow, then we don't need to schedule.
  defp needs_job?(es) do
    has_deadline?(es) and es.late_submit == :disallow
  end

  defp has_deadline?(effective_settings) do
    effective_settings.end_date != nil or effective_settings.time_limit > 0
  end

end
