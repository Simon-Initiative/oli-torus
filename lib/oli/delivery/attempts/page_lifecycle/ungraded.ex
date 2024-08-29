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

  alias Oli.Delivery.Attempts.Core.{ResourceAttempt}
  alias Oli.Delivery.Attempts.PageLifecycle.Common

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
        Appsignal.instrument("Ungraded: AttemptState.fetch_attempt_state", fn ->
          AttemptState.fetch_attempt_state(latest_resource_attempt, page_revision)
        end)

      {:ok, {:in_progress, attempt_state}}
    end
  end

  @impl Lifecycle
  @decorate transaction_event("Ungraded.finalize")
  def finalize(%FinalizationContext{
        resource_attempt: %ResourceAttempt{lifecycle_state: :active} = resource_attempt,
        effective_settings: effective_settings
      }) do
    now = DateTime.utc_now()

    update_resource_attempt(resource_attempt, %{
      date_evaluated: now,
      date_submitted: now,
      lifecycle_state: :evaluated
    })

    {:ok,
    %FinalizationSummary{
      graded: false,
      lifecycle_state: :evaluated,
      resource_access: nil,
      part_attempt_guids: nil,
      effective_settings: effective_settings
    }}
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
  def start(%VisitContext{} = context) do
    {:ok, resource_attempt} = Hierarchy.create(context)

    AttemptState.fetch_attempt_state(resource_attempt, context.page_revision)
    |> update_progress(resource_attempt)
  end

  @decorate transaction_event("Ungraded.update_progress")
  defp update_progress({:ok, state}, %ResourceAttempt{
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
    |> do_update_progress(number_of_scorable_activities)

    {:ok, state}

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
