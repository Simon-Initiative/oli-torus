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

  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Attempts.ActivityLifecycle.{Evaluate, Persistence}
  alias Oli.Delivery.Attempts.PageLifecycle.Common

  @moduledoc """
  Implementation of a page Lifecycle behaviour for ungraded pages.

  Ungraded pages implicitly start a new attempt when a student visits the page.

  For ungraded pages we can safely throw away an existing resource attempt and create a new one
  in the case that the attempt was pinned to an older revision of the resource. This allows newly published
  changes to the resource to be seen after a user has visited the resource previously.
  """

  @behaviour Lifecycle

  @impl Lifecycle
  def visit(
        %VisitContext{
          latest_resource_attempt: latest_resource_attempt,
          page_revision: page_revision
        } = context
      ) do
    if is_nil(latest_resource_attempt) or latest_resource_attempt.revision_id != page_revision.id or
         latest_resource_attempt.lifecycle_state == :evaluated do
      case start(context) do
        {:ok, %AttemptState{} = attempt_state} ->
          {:ok, {:in_progress, attempt_state}}

        error ->
          error
      end
    else
      {:ok, attempt_state} =
        AttemptState.fetch_attempt_state(latest_resource_attempt, page_revision)

      {:ok, {:in_progress, attempt_state}}
    end
  end

  @impl Lifecycle
  def finalize(%FinalizationContext{
        resource_attempt: %ResourceAttempt{lifecycle_state: :active} = resource_attempt,
        datashop_session_id: datashop_session_id
      }) do
    # Collect all of the part attempt guids for all of the activities that get finalized
    with {:ok, part_attempt_guids} <-
           finalize_activity_and_part_attempts(resource_attempt, datashop_session_id),
         {:ok, resource_attempt} <- mark_resource_attempt_evaluated(resource_attempt) do
      {:ok,
       %FinalizationSummary{
         lifecycle_state: :evaluated,
         resource_access: Oli.Repo.get(ResourceAccess, resource_attempt.resource_access_id),
         part_attempt_guids: part_attempt_guids
       }}
    else
      error -> error
    end
  end

  defp finalize_activity_and_part_attempts(resource_attempt, datashop_session_id) do
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

  def mark_resource_attempt_evaluated(resource_attempt) do
    now = DateTime.utc_now()

    update_resource_attempt(resource_attempt, %{
      date_evaluated: now,
      date_submitted: now,
      lifecycle_state: :evaluated
    })
  end

  @impl Lifecycle
  @spec review(Oli.Delivery.Attempts.PageLifecycle.ReviewContext.t()) ::
          {:ok,
           {:finalized, Oli.Delivery.Attempts.PageLifecycle.AttemptState.t()}
           | {:in_progress, Oli.Delivery.Attempts.PageLifecycle.AttemptState.t()}}
  def review(%ReviewContext{} = context) do
    Common.review(context)
  end

  @impl Lifecycle
  def start(%VisitContext{} = context) do
    {:ok, resource_attempt} = Hierarchy.create(context)

    AttemptState.fetch_attempt_state(resource_attempt, context.page_revision)
    |> update_progress(resource_attempt)
  end

  defp update_progress({:ok, activity_map}, %ResourceAttempt{
         resource_access_id: resource_access_id
       }) do
    number_of_activities = Map.keys(activity_map) |> Enum.count()

    Oli.Delivery.Attempts.Core.get_resource_access(resource_access_id)
    |> do_update_progress(number_of_activities)

    {:ok, activity_map}
  end

  defp update_progress(other, _) do
    other
  end

  defp do_update_progress(resource_access, 0) do
    Oli.Delivery.Metrics.mark_progress_completed(resource_access)
  end

  defp do_update_progress(resource_access, _) do
    Oli.Delivery.Metrics.reset_progress(resource_access)
  end
end
