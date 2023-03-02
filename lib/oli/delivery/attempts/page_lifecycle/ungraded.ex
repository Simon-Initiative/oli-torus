defmodule Oli.Delivery.Attempts.PageLifecycle.Ungraded do
  alias Oli.Delivery.Attempts.Hierarchy

  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    ReviewContext,
    FinalizationContext,
    AttemptState,
    Lifecycle,
    Hierarchy
  }
  alias Oli.Delivery.Attempts.Core.ResourceAttempt

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
    if is_nil(latest_resource_attempt) or latest_resource_attempt.revision_id != page_revision.id do
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
  def finalize(%FinalizationContext{} = _context) do
    {:error, {:unsupported}}
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

  defp update_progress({:ok, activity_map}, %ResourceAttempt{resource_access_id: resource_access_id}) do

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
