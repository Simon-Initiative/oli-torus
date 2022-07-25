defmodule Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker do
  @moduledoc """
  An Oban worker driven LMS grade update.

  Called via the `create` function, which takes a resource access id and an update type (:inline, :manual, :manual_batch).

  This works by first fetching the `%ResourceAccess` record, and then posts the score and out_of found their
  to the line item in the LMS. The line item is created if it doesn't already exist. Success and failure are tracked
  via `%LMSGradeUpdate` records which hang off of the `%ResourceAccess` record.

  It is important that we fetch the ResourceAccess record just in time to make this robust to the chance that students can be finalizing
  additional attempts prior to the execution of this (potentially) deferred job.  An example series of events that can easily
  lead to this situation:

  1. Student completes their first attempt and receives a 7/10.
  2. This job executes, but fails (say due to a network timeout).  The job is rescheduled for a second attempt.
  3. Meanwhile, the student - not satisfied with a 7/10 - takes and finishes a second attempt receiving 9/10.
  4. Our Oban infrastructure detects this new job to be a duplicate of an existing and simply merges the two jobs.
  5. When the original job finally executes in its second attempt, the "just in time" read of the %ResourceAccess record
     results in the correct grade (9/10) being sent.
  """

  # See the Oban docs for complete understanding of how these settings work, but
  # comments here briefly describe why they are set this way
  use Oban.Worker,
    queue: :grades,
    max_attempts: 5,
    unique: [
      # Only consider the access record id in determining job uniqueness, this will
      # cause jobs of different types (:manual, :inline, :manual_batch) jobs to conflict
      # and essentially merge
      keys: [:resource_access_id],

      # Consider completed jobs to be duplicates the entire time they are retained
      period: :infinity,

      # Only detect conflicts on jobs that are available, scheduled, or retryable.
      # Once a job is completed or discarded we no longer want to consider it for duplicate checks
      states: [:available, :scheduled, :retryable]
    ]

  import Ecto.Query, warn: false
  alias Oli.Repo

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    LMSGradeUpdate
  }

  @doc """
  Create a grade update worker, given a resource_access_id and a job type.  The job type
  is one of `[:inline, :manual, :manual_batch]`

  Emits broadcasted PubSub events to allow client code to monitor the lifecycle of the grade update.
  The status events emitted are: `[:queued, :running, :success, :failure, :not_synced, :retrying]`

  - `:queued`: The grade update request is queued for its initial execution
  - `:running`: The grade update request has started execution
  - `:success`: The grade update request succeeded
  - `:failure`: The grade update request failed permanently after exhausting all retry attempts
  - `:not_synced`: The grade update request was not actually run due to LMS grade passback not being enabled
  - `:retrying`: The grade update request failed, but is queued for a retry

  """
  def create(section_id, resource_access_id, update_type) do
    case Oli.Delivery.Attempts.PageLifecycle.GradeUpdateWorker.new(
           %{resource_access_id: resource_access_id, type: update_type, section_id: section_id},
           replace: [:args]
         )
         |> Oban.insert() do
      {:ok, job} ->
        Oli.Delivery.Attempts.PageLifecycle.Broadcaster.broadcast_lms_grade_update(
          section_id,
          resource_access_id,
          job,
          :queued,
          nil
        )

        {:ok, job}

      e ->
        e
    end
  end

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "resource_access_id" => resource_access_id,
            "type" => type,
            "section_id" => section_id
          }
        } = job
      ) do
    Oli.Delivery.Attempts.PageLifecycle.Broadcaster.broadcast_lms_grade_update(
      section_id,
      resource_access_id,
      job,
      :running,
      nil
    )

    case Oli.Delivery.Attempts.Core.get_resource_access(resource_access_id) do
      nil ->
        {:error, "Unknown resource access"}

      %ResourceAccess{
        user: user,
        section: section
      } = resource_access ->
        update_grade(user, section, resource_access, type, job)
    end
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp access_token_provider(section) do
    fn ->
      {_deployment, registration} =
        Oli.Delivery.Sections.get_deployment_registration_from_section(section)

      Lti_1p3.Tool.Services.AccessToken.fetch_access_token(registration, Oli.Grading.ags_scopes(), host())
    end
  end

  defp update_grade(user, section, resource_access, type, job) do
    case Oli.Grading.send_score_to_lms(
           section,
           user,
           resource_access,
           access_token_provider(section)
         ) do
      {:error, e} ->
        Oli.Utils.Appsignal.capture_error(e)

        track_failure(
          e,
          resource_access,
          type,
          job,
          section
        )

        {:error, e}

      {:ok, :synced} ->
        track_success(
          resource_access,
          type,
          job,
          section
        )

      {:ok, :not_synced} ->
        track_not_synced(
          resource_access,
          type,
          job,
          section
        )

      # To be as robust as possible, catch a wildcard and treat that as simply an unknown error
      _ ->
        Oli.Utils.Appsignal.capture_error("Unknown error")

        track_failure(
          "Unknown error",
          resource_access,
          type,
          job,
          section
        )

        {:error, "Unknown error"}
    end
  end

  defp track(
         access_updater,
         result,
         details,
         %ResourceAccess{id: resource_access_id, score: score, out_of: out_of},
         type,
         job,
         section
       ) do
    persistence_result =
      case Oli.Delivery.Attempts.Core.get_resource_access(resource_access_id) do
        nil ->
          {:error, "Unknown resource access"}

        %ResourceAccess{} = resource_access ->
          %{attempt: attempt} = job

          attrs = %{
            score: score,
            out_of: out_of,
            type: String.to_existing_atom(type),
            result: result,
            details: details,
            attempt_number: attempt,
            resource_access_id: resource_access_id
          }

          Repo.transaction(fn _ ->
            case Oli.Delivery.Attempts.Core.create_lms_grade_update(attrs) do
              {:ok, %LMSGradeUpdate{id: id}} ->
                case Oli.Delivery.Attempts.Core.update_resource_access(
                       resource_access,
                       access_updater.(id)
                     ) do
                  {:ok, ra} ->
                    ra

                  {:error, e} ->
                    Repo.rollback(e)
                end

              {:error, e} ->
                Repo.rollback(e)
            end
          end)
      end

    # Broadcast the LMS grade update result to the system, notice that we do this *outside* of
    # the above transaction to guarantee that client code that might perform a read in response to this
    # sees the database in a consistent state.
    Oli.Delivery.Attempts.PageLifecycle.Broadcaster.broadcast_lms_grade_update(
      section.id,
      resource_access_id,
      job,

      # Report the status as either [:success, :failure, :retrying, :not_synced]
      case {result, job} do
        {:failure, %Oban.Job{attempt: attempt, max_attempts: max_attempts}}
        when attempt < max_attempts ->
          :retrying

        {other, _} ->
          other
      end,
      details
    )

    persistence_result
  end

  def track_failure(details, resource_access, type, job, section) do
    fn id ->
      %{
        last_grade_update_id: id
      }
    end
    |> track(:failure, details, resource_access, type, job, section)
  end

  def track_success(resource_access, type, job, section) do
    fn id ->
      %{
        last_grade_update_id: id,
        last_successful_grade_update_id: id
      }
    end
    |> track(:success, nil, resource_access, type, job, section)
  end

  def track_not_synced(resource_access, type, job, section) do
    fn id ->
      %{
        last_grade_update_id: id
      }
    end
    |> track(:not_synced, nil, resource_access, type, job, section)
  end

  def get_jobs() do
    Repo.all(from(j in Oban.Job, where: j.queue == "grades"))
  end
end
