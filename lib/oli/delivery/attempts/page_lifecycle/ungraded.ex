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

  alias Oli.Delivery.Attempts.PageLifecycle.Common
  alias Oli.Resources.Revision

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
  end
end
