defmodule Oli.Delivery.Attempts.PageLifecycle.Ungraded do
  import Ecto.Query, warn: false
  import Oli.Delivery.Attempts.Core

  alias Oli.Delivery.Attempts.Hierarchy

  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    ReviewContext,
    FinalizationContext,
    FinalizationSummary,
    AttemptState,
    Lifecycle,
    Hierarchy
  }

  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}
  alias Oli.Delivery.Attempts.PageLifecycle.Common
  alias Oli.Delivery.Attempts.PageLifecycle.Graded
  alias Oli.Delivery.ActivityProvider.Result
  alias Oli.Resources.PageContent

  @moduledoc """
  Implementation of a page Lifecycle behaviour for ungraded pages.

  Ungraded pages implicitly start a new attempt when a student visits the page.

  For ungraded pages we can safely throw away an existing resource attempt and create a new one
  in the case that the attempt was pinned to an older revision of the resource. This allows newly published
  changes to the resource to be seen after a user has visited the resource previously.
  """
  use Appsignal.Instrumentation.Decorators

  @behaviour Lifecycle

  @impl Lifecycle
  @decorate transaction_event("Ungraded.visit")
  def visit(
        %VisitContext{
          latest_resource_attempt: latest_resource_attempt,
          page_revision: page_revision
        } = context
      ) do
    if needs_new_attempt?(latest_resource_attempt, page_revision) do
      start_from_visit(context)
    else
      {:ok, attempt_state} =
        Appsignal.instrument("Ungraded: AttemptState.fetch_attempt_state", fn ->
          AttemptState.fetch_attempt_state(latest_resource_attempt, page_revision)
        end)

      maybe_recover_empty_attempt(context, attempt_state)
    end
  end

  @impl Lifecycle
  @spec finalize(FinalizationContext.t()) ::
          {:ok, FinalizationSummary.t()} | {:error, term()}
  @decorate transaction_event("Ungraded.finalize")
  def finalize(%FinalizationContext{
        resource_attempt: %ResourceAttempt{} = resource_attempt,
        effective_settings: effective_settings
      }) do
    lock_resource_access(resource_attempt.resource_access_id)

    case get_resource_attempt_by(id: resource_attempt.id) do
      %ResourceAttempt{lifecycle_state: :active} = current_resource_attempt ->
        finalize_active_attempt(current_resource_attempt, effective_settings)

      _ ->
        {:error, {:already_submitted}}
    end
  end

  defp finalize_active_attempt(resource_attempt, effective_settings) do
    now = DateTime.utc_now()

    update_attrs =
      determine_finalization_attrs(resource_attempt, now)

    with {:ok, updated_resource_attempt} <-
           update_resource_attempt(resource_attempt, update_attrs),
         {:ok, _resource_access} <-
           maybe_mark_adaptive_progress_completed(updated_resource_attempt) do
      {:ok,
       %FinalizationSummary{
         graded: false,
         lifecycle_state: updated_resource_attempt.lifecycle_state,
         resource_access: nil,
         part_attempt_guids: nil,
         effective_settings: effective_settings
       }}
    end
  end

  @impl Lifecycle
  @spec review(Oli.Delivery.Attempts.PageLifecycle.ReviewContext.t()) ::
          {:ok,
           {:finalized, Oli.Delivery.Attempts.PageLifecycle.AttemptState.t()}
           | {:in_progress, Oli.Delivery.Attempts.PageLifecycle.AttemptState.t()}}
  @decorate transaction_event("Ungraded.review")
  def review(%ReviewContext{} = context) do
    Common.review(context)
  end

  @impl Lifecycle
  @decorate transaction_event("Ungraded.start")
  def start(%VisitContext{page_revision: page_revision} = context) do
    realization = Hierarchy.realize(context)

    case context.latest_resource_attempt do
      nil ->
        start(context, realization, page_revision)

      %ResourceAttempt{resource_access_id: resource_access_id} ->
        lock_resource_access(resource_access_id)

        refreshed_context = refresh_latest_attempt(context, resource_access_id)

        case needs_new_attempt?(refreshed_context.latest_resource_attempt, page_revision) do
          true -> start(refreshed_context, realization, page_revision)
          false -> {:error, {:active_attempt_present}}
        end
    end
  end

  defp start(context, realization, page_revision) do
    {:ok, resource_attempt} = Hierarchy.create(context, realization)

    AttemptState.fetch_attempt_state(resource_attempt, context.page_revision)
    |> update_progress(page_revision, resource_attempt)
  end

  defp start_from_visit(%VisitContext{page_revision: page_revision} = context) do
    realization = Hierarchy.realize(context)

    case context.latest_resource_attempt do
      nil ->
        start_visit_attempt(context, realization)

      %ResourceAttempt{resource_access_id: resource_access_id} ->
        lock_resource_access(resource_access_id)

        refreshed_context = refresh_latest_attempt(context, resource_access_id)

        case needs_new_attempt?(refreshed_context.latest_resource_attempt, page_revision) do
          true -> start_visit_attempt(refreshed_context, realization)
          false -> visit(refreshed_context)
        end
    end
  end

  defp start_visit_attempt(context, realization) do
    case start(context, realization, context.page_revision) do
      {:ok, %AttemptState{} = attempt_state} -> {:ok, {:in_progress, attempt_state}}
      error -> error
    end
  end

  defp maybe_recover_empty_attempt(
         _context,
         %AttemptState{attempt_hierarchy: attempt_hierarchy} = attempt_state
       )
       when map_size(attempt_hierarchy) > 0 do
    {:ok, {:in_progress, attempt_state}}
  end

  defp maybe_recover_empty_attempt(
         %VisitContext{page_revision: %{content: %{"advancedDelivery" => true}}},
         attempt_state
       ) do
    {:ok, {:in_progress, attempt_state}}
  end

  defp maybe_recover_empty_attempt(%VisitContext{} = context, attempt_state) do
    if PageContent.contains_activity_opportunity?(context.page_revision.content) do
      audience_filtered_content =
        Oli.Delivery.Audience.filter_for_role(
          context.audience_role,
          context.page_revision.content
        )

      maybe_recover_audience_attempt(context, attempt_state, audience_filtered_content)
    else
      {:ok, {:in_progress, attempt_state}}
    end
  end

  defp maybe_recover_audience_attempt(context, attempt_state, audience_filtered_content) do
    if PageContent.contains_activity_opportunity?(audience_filtered_content) do
      realization = Hierarchy.realize(context)

      case realization do
        %Result{prototypes: []} ->
          {:ok, {:in_progress, attempt_state}}

        %Result{} ->
          recover_empty_attempt(context, attempt_state, realization)
      end
    else
      {:ok, {:in_progress, attempt_state}}
    end
  end

  defp recover_empty_attempt(
         %VisitContext{} = context,
         %AttemptState{resource_attempt: resource_attempt},
         realization
       ) do
    # Instructor customizations can remove every activity from a practice page, producing an
    # empty active attempt. If an activity is later restored, replace that empty attempt so the
    # learner is not permanently pinned to the activity-free transformed content.
    lock_resource_access(resource_attempt.resource_access_id)

    refreshed_context = refresh_latest_attempt(context, resource_attempt.resource_access_id)
    latest_resource_attempt = refreshed_context.latest_resource_attempt

    case latest_resource_attempt do
      %ResourceAttempt{id: id, lifecycle_state: :active} when id == resource_attempt.id ->
        replace_empty_attempt(context, resource_attempt, realization)

      %ResourceAttempt{} ->
        case needs_new_attempt?(latest_resource_attempt, context.page_revision) do
          true -> start_visit_attempt(refreshed_context, realization)
          false -> visit(refreshed_context)
        end
    end
  end

  defp refresh_latest_attempt(context, resource_access_id) do
    %{
      context
      | latest_resource_attempt: get_latest_resource_attempt_for_access(resource_access_id)
    }
  end

  defp replace_empty_attempt(context, resource_attempt, realization) do
    now = DateTime.utc_now()

    with {:ok, superseded_attempt} <-
           update_resource_attempt(
             resource_attempt,
             determine_finalization_attrs(resource_attempt, now)
           ),
         {:ok, attempt_state} <-
           start(
             %{context | latest_resource_attempt: superseded_attempt},
             realization,
             context.page_revision
           ) do
      {:ok, {:in_progress, attempt_state}}
    end
  end

  @decorate transaction_event("Ungraded.update_progress")
  defp update_progress({:ok, state}, page_revision, %ResourceAttempt{
         resource_access_id: resource_access_id
       }) do
    number_of_scorable_activities =
      Map.values(state.attempt_hierarchy)
      |> Enum.map(fn args ->
        # The adaptive page and basic page have different shapes of their attempt hierarchy
        # state.  We handle only the basic page here, and the adaptive page state gets mapped
        # to mimic attempts that are scoreable.  We can do this because we know that it is
        # impossible for an adaptive page to only have non-scoreable activities.
        case args do
          {attempt, _} -> attempt
          _ -> %{scoreable: true}
        end
      end)
      |> Enum.filter(fn attempt -> attempt.scoreable end)
      |> Enum.count()

    Oli.Delivery.Attempts.Core.get_resource_access(resource_access_id)
    |> do_update_progress(page_revision.full_progress_pct, number_of_scorable_activities)

    {:ok, state}
  end

  defp update_progress(other, _, _) do
    other
  end

  # Update the progress of the resource access based on the number of scorable activities
  # and the full progress percentage of the page revision.  If the full progress percentage
  # OR the number of scorable activities is 0, then the progress is marked as completed.

  defp do_update_progress(resource_access, _, 0) do
    Oli.Delivery.Metrics.mark_progress_completed(resource_access)
  end

  defp do_update_progress(resource_access, 0, _) do
    Oli.Delivery.Metrics.mark_progress_completed(resource_access)
  end

  # If the progress is nil, then we reset the progress to 0

  defp do_update_progress(%{progress: nil} = resource_access, _, _) do
    Oli.Delivery.Metrics.reset_progress(resource_access)
  end

  # Otherwise, we do not update the progress, preserving the existing progress from
  # previous attempts on this page

  defp do_update_progress(resource_access, _, _) do
    {:ok, resource_access}
  end

  # We need a new attempt when:

  # There isn't a previous attempt
  defp needs_new_attempt?(nil, _), do: true
  # The previous attempt is evaluated
  defp needs_new_attempt?(%{lifecycle_state: :evaluated}, _), do: true
  # The previous attempt's page revision differs from the current page revision
  defp needs_new_attempt?(%{revision_id: revision_id}, %{id: id}) do
    revision_id != id
  end

  defp determine_finalization_attrs(
         %ResourceAttempt{revision: %{content: %{"advancedDelivery" => true}}} = resource_attempt,
         now
       ) do
    adaptive_finalization_attrs(resource_attempt, now)
  end

  defp determine_finalization_attrs(_resource_attempt, now) do
    %{
      date_evaluated: now,
      date_submitted: now,
      lifecycle_state: :evaluated
    }
  end

  defp adaptive_finalization_attrs(
         %ResourceAttempt{revision: %{content: %{"advancedDelivery" => true}}} = resource_attempt,
         now
       ) do
    activity_attempts =
      Oli.Delivery.Attempts.Core.get_latest_activity_attempts(resource_attempt.id)

    cond do
      adaptive_all_evaluated?(activity_attempts) ->
        {score, out_of} =
          activity_attempts
          |> Enum.filter(& &1.scoreable)
          |> Enum.reduce({0.0, 0.0}, fn activity_attempt, {score, out_of} ->
            {score + (activity_attempt.score || 0.0), out_of + (activity_attempt.out_of || 0.0)}
          end)
          |> Graded.ensure_valid_grade()

        %{
          score: score,
          out_of: out_of,
          date_evaluated: now,
          date_submitted: now,
          lifecycle_state: :evaluated
        }

      adaptive_pending_manual_grading?(activity_attempts) ->
        %{
          score: nil,
          out_of: nil,
          date_evaluated: nil,
          date_submitted: now,
          lifecycle_state: :submitted
        }

      true ->
        %{
          date_evaluated: now,
          date_submitted: now,
          lifecycle_state: :evaluated
        }
    end
  end

  defp adaptive_all_evaluated?(activity_attempts) do
    Enum.all?(activity_attempts, fn activity_attempt ->
      activity_attempt.lifecycle_state == :evaluated or !activity_attempt.scoreable
    end)
  end

  defp adaptive_pending_manual_grading?(activity_attempts) do
    Enum.any?(activity_attempts, &(&1.lifecycle_state == :submitted)) and
      Enum.all?(activity_attempts, fn
        %ActivityAttempt{lifecycle_state: lifecycle_state, scoreable: scoreable} ->
          lifecycle_state in [:evaluated, :submitted] or !scoreable
      end)
  end

  defp maybe_mark_adaptive_progress_completed(%ResourceAttempt{
         revision: %{content: %{"advancedDelivery" => true}},
         resource_access_id: resource_access_id
       }) do
    Oli.Delivery.Metrics.mark_progress_completed(resource_access_id)
  end

  defp maybe_mark_adaptive_progress_completed(_), do: {:ok, nil}
end
