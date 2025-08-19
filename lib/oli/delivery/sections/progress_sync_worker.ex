defmodule Oli.Delivery.Sections.ProgressSyncWorker do
  @moduledoc """
  An Oban worker for synchronizing progress grades to the LMS.

  This worker handles the reliable delivery of progress-based scores to the LMS
  gradebook using LTI AGS 2.0. It supports both individual and batch processing
  with proper retry logic and rate limiting.

  The worker is designed to be:
  - Reliable: Proper retry logic with exponential backoff
  - Efficient: Batch processing and deduplication
  - Traceable: Comprehensive logging and telemetry
  - Rate-limited: Respects LMS API constraints
  """

  use Oban.Worker,
    queue: :progress_grades,
    max_attempts: 5,
    unique: [
      # Deduplicate based on section and user to prevent duplicate syncs
      keys: [:section_id, :user_id],
      # Allow replacement of older jobs with newer ones
      period: 60,
      # Only consider available, scheduled, or retryable jobs for deduplication
      states: [:available, :scheduled, :retryable]
    ]

  require Logger

  import Ecto.Query, warn: false

  alias Oli.Repo

  alias Oli.Delivery.Sections.{
    Section,
    ProgressScoringManager,
    ProgressGradeCalculator,
    ProgressGradeLineItem
  }

  alias Oli.Accounts.User
  alias Lti_1p3.Tool.Services.AGS
  alias Lti_1p3.Tool.Services.AGS.Score

  @doc """
  Creates a progress sync job for a single user.
  """
  def create(section_id, user_id, opts \\ []) do
    %{
      section_id: section_id,
      user_id: user_id,
      type: :individual
    }
    |> new(opts)
    |> Oban.insert()
  end

  @doc """
  Creates a batch progress sync job for multiple users.
  """
  def create_batch(section_id, user_ids, opts \\ []) when is_list(user_ids) do
    # Create individual jobs for each user to allow for proper deduplication
    # and individual retry handling
    jobs =
      Enum.map(user_ids, fn user_id ->
        %{
          section_id: section_id,
          user_id: user_id,
          type: :batch
        }
        |> new(opts)
      end)

    Oban.insert_all(jobs)
  end

  @doc """
  Creates a manual sync job triggered by instructor.
  """
  def create_manual(section_id, user_ids, opts \\ []) when is_list(user_ids) do
    create_batch(section_id, user_ids, Keyword.put(opts, :priority, 1))
  end

  @impl Oban.Worker
  def perform(
        %Oban.Job{
          args: %{
            "section_id" => section_id,
            "user_id" => user_id,
            "type" => type
          }
        } = job
      ) do
    # Emit telemetry for job start
    :telemetry.execute(
      [:oli, :progress_scoring, :sync, :start],
      %{},
      %{section_id: section_id, user_id: user_id, type: type}
    )

    with {:ok, section} <- get_section_with_user(section_id, user_id),
         {:ok, _settings} <- validate_progress_scoring_enabled(section),
         {:ok, container_grades} <- calculate_progress_grade(section_id, user_id),
         {:ok, _results} <- sync_all_container_grades(section, user_id, container_grades) do
      # Emit telemetry for success
      :telemetry.execute(
        [:oli, :progress_scoring, :sync, :success],
        %{duration: job_duration(job)},
        %{section_id: section_id, user_id: user_id, type: type}
      )

      Logger.info("Progress grades synced successfully",
        section_id: section_id,
        user_id: user_id,
        containers_synced: map_size(container_grades)
      )

      :ok
    else
      {:error, reason} = error ->
        # Emit telemetry for failure
        :telemetry.execute(
          [:oli, :progress_scoring, :sync, :failure],
          %{duration: job_duration(job)},
          %{section_id: section_id, user_id: user_id, type: type, reason: reason}
        )

        Logger.error("Progress grade sync failed",
          section_id: section_id,
          user_id: user_id,
          reason: inspect(reason)
        )

        error
    end
  end

  # Private helper functions

  defp get_section_with_user(section_id, user_id) do
    query =
      from s in Section,
        where: s.id == ^section_id,
        preload: [:lti_1p3_deployment]

    case Repo.one(query) do
      nil ->
        {:error, :section_not_found}

      section ->
        case Repo.get(User, user_id) do
          nil -> {:error, :user_not_found}
          user -> {:ok, Map.put(section, :user, user)}
        end
    end
  end

  defp validate_progress_scoring_enabled(section) do
    case ProgressScoringManager.get_progress_scoring_settings(section.id) do
      {:ok, %{enabled: true} = settings} ->
        if section.grade_passback_enabled do
          {:ok, settings}
        else
          {:error, :grade_passback_disabled}
        end

      {:ok, %{enabled: false}} ->
        {:error, :progress_scoring_disabled}

      error ->
        error
    end
  end

  defp calculate_progress_grade(section_id, user_id) do
    # Calculate grades per container for individual line items
    case ProgressGradeCalculator.calculate_grade_per_container(section_id, user_id) do
      {:ok, container_grades} when map_size(container_grades) > 0 ->
        # Filter out containers with no score to sync
        valid_grades =
          container_grades
          |> Enum.filter(fn {_container_id, grade_data} ->
            not is_nil(grade_data.score)
          end)
          |> Enum.into(%{})

        if map_size(valid_grades) > 0 do
          {:ok, valid_grades}
        else
          {:error, :no_scores_to_sync}
        end

      {:ok, _empty} ->
        {:error, :no_containers_configured}

      error ->
        error
    end
  end

  defp sync_all_container_grades(section, user_id, container_grades) do
    # Get access token once for all containers
    with {:ok, access_token} <- get_access_token(section),
         {:ok, user} <- get_user_with_sub(user_id) do
      # Sync each container's grade to its own line item
      results =
        container_grades
        |> Enum.map(fn {container_id, grade_data} ->
          sync_container_grade(section, user, container_id, grade_data, access_token)
        end)

      # Check if all syncs succeeded
      failed_syncs =
        Enum.filter(results, fn
          {:error, _} -> true
          _ -> false
        end)

      if Enum.empty?(failed_syncs) do
        {:ok, results}
      else
        Logger.error("Some container grades failed to sync",
          section_id: section.id,
          user_id: user_id,
          failures: length(failed_syncs)
        )

        {:error, {:partial_sync_failure, failed_syncs}}
      end
    else
      error -> error
    end
  end

  defp sync_container_grade(section, user, container_id, grade_data, access_token) do
    # Create a sync log for this container
    with {:ok, sync_log} <-
           create_container_sync_log(section.id, user.id, container_id, grade_data),
         {:ok, line_item} <-
           get_or_create_container_line_item(section, container_id, access_token),
         {:ok, _response} <- post_score_to_lms(user, line_item, grade_data, access_token) do
      # Mark sync as successful
      ProgressScoringManager.mark_sync_success(sync_log)
      {:ok, {:synced, container_id}}
    else
      {:error, reason} = error ->
        Logger.error("Failed to sync container grade",
          section_id: section.id,
          user_id: user.id,
          container_id: container_id,
          reason: inspect(reason)
        )

        error
    end
  end

  defp create_container_sync_log(section_id, user_id, _container_id, grade_data) do
    # TODO: Consider adding container_id to sync log schema for better tracking
    # For now, we create a standard sync log per container
    ProgressScoringManager.create_pending_sync_log(
      section_id,
      user_id,
      grade_data.progress_percentage,
      grade_data.score,
      grade_data.out_of
    )
  end

  defp get_access_token(section) do
    {_deployment, registration} =
      Oli.Delivery.Sections.get_deployment_registration_from_section(section)

    case Lti_1p3.Tool.Services.AccessToken.fetch_access_token(
           registration,
           ["https://purl.imsglobal.org/spec/lti-ags/scope/score"],
           host()
         ) do
      {:ok, access_token} -> {:ok, access_token}
      error -> error
    end
  end

  defp host() do
    Application.get_env(:oli, OliWeb.Endpoint)
    |> Keyword.get(:url)
    |> Keyword.get(:host)
  end

  defp get_or_create_container_line_item(section, container_id, access_token) do
    ProgressGradeLineItem.fetch_or_create_line_item_for_container(
      section,
      container_id,
      access_token
    )
  end

  defp get_user_with_sub(user_id) do
    case Repo.get(User, user_id) do
      nil -> {:error, :user_not_found}
      %User{sub: nil} -> {:error, :user_missing_sub}
      user -> {:ok, user}
    end
  end

  defp post_score_to_lms(user, line_item, grade_data, access_token) do
    score = create_ags_score(user.sub, grade_data)

    case AGS.post_score(score, line_item, access_token) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, {:lms_api_error, reason}}
    end
  end

  defp create_ags_score(user_sub, grade_data) do
    {:ok, timestamp} = DateTime.now("Etc/UTC")

    %Score{
      userId: user_sub,
      scoreGiven: grade_data.score,
      scoreMaximum: grade_data.out_of,
      activityProgress: "Completed",
      gradingProgress: "FullyGraded",
      timestamp: DateTime.to_iso8601(timestamp),
      comment: "Progress score automatically calculated"
    }
  end

  defp job_duration(job) do
    case DateTime.from_unix(job.inserted_at, :second) do
      {:ok, start_time} ->
        DateTime.diff(DateTime.utc_now(), start_time, :millisecond)

      _ ->
        0
    end
  end
end
