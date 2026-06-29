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
      case start(context) do
        {:ok, %AttemptState{} = attempt_state} ->
          {:ok, {:in_progress, attempt_state}}

        error ->
          error
      end
    else
      {:ok, attempt_state} =
        Appsignal.instrument("Ungraded: AttemptState.fetch_attempt_state", fn ->
          AttemptState.fetch_attempt_state(latest_resource_attempt, page_revision)
        end)

      {:ok, {:in_progress, attempt_state}}
    end
  end

  @impl Lifecycle
  @spec finalize(FinalizationContext.t()) ::
          {:ok, FinalizationSummary.t()} | {:error, term()}
  @decorate transaction_event("Ungraded.finalize")
  def finalize(%FinalizationContext{
        resource_attempt: %ResourceAttempt{lifecycle_state: :active} = resource_attempt,
        effective_settings: effective_settings
      }) do
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
    {:ok, resource_attempt} = Hierarchy.create(context)

    AttemptState.fetch_attempt_state(resource_attempt, context.page_revision)
    |> update_progress(page_revision, resource_attempt)
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
    resource_access_id
    |> Oli.Delivery.Attempts.Core.get_resource_access()
    |> Oli.Delivery.Metrics.mark_progress_completed()
  end

  defp maybe_mark_adaptive_progress_completed(_), do: {:ok, nil}
end
