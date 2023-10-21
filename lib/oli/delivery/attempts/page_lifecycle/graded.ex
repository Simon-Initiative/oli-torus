defmodule Oli.Delivery.Attempts.PageLifecycle.Graded do
  alias Oli.Delivery.Attempts.Hierarchy

  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    ReviewContext,
    FinalizationContext,
    FinalizationSummary,
    HistorySummary,
    AttemptState,
    Lifecycle,
    Hierarchy
  }

  alias Oli.Delivery.Settings
  alias Oli.Delivery.Settings.Combined
  alias Oli.Delivery.Attempts.Scoring
  alias Oli.Delivery.Attempts.ActivityLifecycle.{Evaluate, Persistence}
  alias Oli.Delivery.Evaluation.Result
  alias Oli.Delivery.Attempts.PageLifecycle.Common
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Attempts.Core

  import Oli.Delivery.Attempts.Core
  import Ecto.Query, warn: false

  @moduledoc """
  Implementation of a page Lifecycle behaviour for graded pages.
  """

  @behaviour Lifecycle

  @impl Lifecycle
  def visit(%VisitContext{
        latest_resource_attempt: latest_resource_attempt,
        page_revision: page_revision,
        section_slug: section_slug,
        user: user
      }) do
    # There is no "active" attempt if there has never been an attempt or if the latest
    # attempt has been finalized or submitted
    if is_nil(latest_resource_attempt) or
         latest_resource_attempt.lifecycle_state == :submitted or
         latest_resource_attempt.lifecycle_state == :evaluated do
      # Graded pages must be started explicitly by the student, giving them to chance to
      # see how many attempts, etc.

      {access, attempts} =
        get_resource_attempt_history(page_revision.resource_id, section_slug, user.id)

      graded_attempts = Enum.filter(attempts, fn a -> a.revision.graded == true end)

      {:ok,
       {:not_started,
        %HistorySummary{
          resource_access: access,
          resource_attempts: graded_attempts
        }}}
    else
      # Unlike ungraded pages, for graded pages we do not throw away attempts and create anew in the case
      # where the resource revision has changed.  Instead we return back the existing attempt tree and force
      # the page renderer to resolve this discrepancy by indicating the "revised" state.

      {:ok, attempt_state} =
        AttemptState.fetch_attempt_state(latest_resource_attempt, page_revision)

      if page_revision.id !== latest_resource_attempt.revision_id do
        {:ok, {:revised, attempt_state}}
      else
        {:ok, {:in_progress, attempt_state}}
      end
    end
  end

  @impl Lifecycle
  def start(
        %VisitContext{
          page_revision: page_revision,
          user: user,
          effective_settings: effective_settings,
          section_slug: section_slug,
          datashop_session_id: datashop_session_id
        } = context
      ) do
    {_, resource_attempts} =
      get_resource_attempt_history(page_revision.resource_id, section_slug, user.id)

    # We want to disregard any attempts that pertained to revisions whose graded status
    # do not match the current graded status. This accommodates the toggling of "graded" status
    # across publications, interwoven with student attempts, to work correctly
    resource_attempts =
      Enum.filter(resource_attempts, fn a -> a.revision.graded == page_revision.graded end)

    case Oli.Delivery.Settings.check_end_date(effective_settings) do
      {:allowed} ->
        case {effective_settings.max_attempts > length(resource_attempts) or
                effective_settings.max_attempts == 0,
              has_any_active_attempts?(resource_attempts)} do
          {true, false} ->
            {:ok, resource_attempt} = Hierarchy.create(context)

            # We possible schedule an auto-submission job (depending on the settings)
            {:ok, resource_attempt} =
              case Oli.Delivery.Attempts.AutoSubmit.Worker.maybe_schedule_auto_submit(
                     effective_settings,
                     section_slug,
                     resource_attempt,
                     datashop_session_id
                   ) do
                {:ok, :not_scheduled} ->
                  {:ok, resource_attempt}

                {:ok, auto_submit_job_id} ->
                  Core.update_resource_attempt(resource_attempt, %{
                    auto_submit_job_id: auto_submit_job_id
                  })
              end

            AttemptState.fetch_attempt_state(resource_attempt, page_revision)

          {true, true} ->
            {:error, {:active_attempt_present}}

          {false, _} ->
            {:error, {:no_more_attempts}}
        end

      {:end_date_passed} ->
        {:error, {:end_date_passed}}
    end
  end

  @impl Lifecycle
  def review(%ReviewContext{} = context) do
    Common.review(context)
  end

  @impl Lifecycle
  def finalize(%FinalizationContext{
        resource_attempt: %ResourceAttempt{lifecycle_state: :active} = resource_attempt,
        section_slug: section_slug,
        datashop_session_id: datashop_session_id,
        effective_settings: effective_settings
      }) do
    # Collect all of the part attempt guids for all of the activities that get finalized
    with {:ok, part_attempt_guids} <-
           finalize_activity_and_part_attempts(resource_attempt, datashop_session_id),
         {:ok, resource_attempt} <-
           roll_up_activities_to_resource_attempt(resource_attempt, effective_settings),
         {:ok, resource_attempt} <- cancel_pending_auto_submit(resource_attempt) do
      case resource_attempt do
        %ResourceAttempt{lifecycle_state: :evaluated} ->
          case roll_up_resource_attempts_to_access(
                 effective_settings,
                 section_slug,
                 resource_attempt.resource_access_id,
                 resource_attempt.was_late
               ) do
            {:ok, resource_access} ->
              {:ok,
               %FinalizationSummary{
                 graded: true,
                 lifecycle_state: :evaluated,
                 resource_access: resource_access,
                 part_attempt_guids: part_attempt_guids,
                 effective_settings: effective_settings
               }}

            error ->
              error
          end

        %ResourceAttempt{lifecycle_state: :submitted, resource_access_id: resource_access_id} ->
          {:ok, resource_access} =
            Oli.Delivery.Metrics.mark_progress_completed(
              Oli.Repo.get(ResourceAccess, resource_access_id)
            )

          {:ok,
           %FinalizationSummary{
             graded: true,
             lifecycle_state: :submitted,
             resource_access: resource_access,
             part_attempt_guids: part_attempt_guids,
             effective_settings: effective_settings
           }}
      end
    else
      error -> error
    end
  end

  def finalize(_), do: {:error, {:already_submitted}}

  defp finalize_activity_and_part_attempts(resource_attempt, datashop_session_id) do
    case resource_attempt.revision do
      # For adaptive pages, we never want to evaluate anything at finalization time
      %{content: %{"advancedDelivery" => true}} ->
        {:ok, []}

      _ ->
        with {_, activity_attempt_values, activity_attempt_params, part_attempt_guids} <-
               Evaluate.update_part_attempts_and_get_activity_attempts(
                 resource_attempt,
                 datashop_session_id
               ),
             {:ok, _} <-
               Persistence.bulk_update_activity_attempts(
                 Enum.join(activity_attempt_values, ", "),
                 activity_attempt_params
               ) do
          {:ok, part_attempt_guids}
        else
          error -> error
        end
    end
  end

  defp cancel_pending_auto_submit(%ResourceAttempt{auto_submit_job_id: nil} = ra), do: {:ok, ra}

  defp cancel_pending_auto_submit(%ResourceAttempt{} = ra) do
    Oli.Delivery.Attempts.AutoSubmit.Worker.cancel_auto_submit(ra)
    Core.update_resource_attempt(ra, %{auto_submit_job_id: nil})
  end

  def roll_up_activities_to_resource_attempt(resource_attempt, %Combined{} = effective_settings) do
    # It is necessary to refetch the resource attempt so that we have the latest view
    # of its state, and to separately fetch the list of most recent attempts for each
    # activity.
    activity_attempts =
      case resource_attempt.revision do
        # For adaptive pages, since we are rolling up to the resource attempt, we must consider
        # both submitted and evaluated attempts
        %{content: %{"advancedDelivery" => true}} ->
          get_latest_non_active_activity_attempts(resource_attempt.id)

        _ ->
          get_latest_activity_attempts(resource_attempt.id)
      end

    if is_evaluated?(activity_attempts) do
      apply_evaluation(resource_attempt, activity_attempts, effective_settings)
    else
      if is_submitted?(activity_attempts) do
        apply_submission(resource_attempt, effective_settings)
      else
        {:ok, resource_attempt}
      end
    end
  end

  defp apply_evaluation(resource_attempt, activity_attempts, %Combined{} = effective_settings) do
    {score, out_of} =
      if Enum.empty?(activity_attempts) do
        # For assessments with empty activities, grant a score or 1.0/1.0
        {1.0, 1.0}
      else
        activity_attempts
        |> Enum.filter(fn activity_attempt -> activity_attempt.scoreable end)
        |> Enum.reduce({0, 0}, &aggregation_reducer/2)
        |> override_out_of(resource_attempt.revision.content)
        |> ensure_valid_grade
      end

    now = DateTime.utc_now()

    update_resource_attempt(resource_attempt, %{
      score: score,
      out_of: out_of,
      date_evaluated: now,
      date_submitted: now,
      lifecycle_state: :evaluated,
      was_late: Settings.was_late?(resource_attempt, effective_settings, now)
    })
  end

  defp apply_submission(resource_attempt, %Combined{} = effective_settings) do
    case resource_attempt.lifecycle_state do
      :active ->
        now = DateTime.utc_now()

        update_resource_attempt(resource_attempt, %{
          date_submitted: now,
          lifecycle_state: :submitted,
          was_late: Settings.was_late?(resource_attempt, effective_settings, now)
        })

      _ ->
        {:ok, resource_attempt}
    end
  end

  defp is_evaluated?(activity_attempts) do
    Enum.all?(activity_attempts, fn aa ->
      aa.lifecycle_state == :evaluated or !aa.scoreable
    end)
  end

  defp is_submitted?(activity_attempts) do
    Enum.all?(activity_attempts, fn aa ->
      aa.lifecycle_state == :evaluated or aa.lifecycle_state == :submitted or !aa.scoreable
    end)
  end

  defp aggregation_reducer(p, {score, out_of}) do
    {score + p.score, out_of + p.out_of}
  end

  defp override_out_of({score, out_of}, %{
         "advancedDelivery" => true,
         "custom" => %{"totalScore" => total_score}
       }) do
    adjusted =
      case total_score do
        value when is_binary(value) ->
          case Float.parse(value) do
            {v, _} -> v
            _ -> out_of
          end

        value when is_float(value) or is_integer(value) ->
          value

        _ ->
          out_of
      end

    {score, adjusted}
  end

  defp override_out_of(grade, _), do: grade

  # Ensure that the out_of is 1.0 or greater, and ensure that
  # the score is between 0.0 and the out_of, inclusive
  def ensure_valid_grade({score, out_of}) do
    out_of = max(out_of, 1.0)
    score = max(score, 0.0) |> min(out_of)

    {score, out_of}
  end

  def ensure_valid_grade(%Result{score: score, out_of: out_of}) do
    ensure_valid_grade({score, out_of})
  end

  def roll_up_resource_attempts_to_access(
        %{scoring_strategy_id: scoring_strategy_id},
        _section_slug,
        resource_access_id,
        was_late
      ) do
    access = Oli.Repo.get(ResourceAccess, resource_access_id)

    graded_attempts =
      get_graded_attempts_from_access(access.id)
      |> Enum.filter(fn ra -> ra.lifecycle_state == :evaluated end)

    {score, out_of} =
      Scoring.calculate_score(scoring_strategy_id, graded_attempts)
      |> ensure_valid_grade()

    update_resource_access(access, %{
      was_late: was_late,
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end
end
