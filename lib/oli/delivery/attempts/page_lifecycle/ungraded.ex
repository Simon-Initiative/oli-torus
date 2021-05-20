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
      {:ok,
       {:in_progress,
        %AttemptState{
          resource_attempt: latest_resource_attempt,
          attempt_hierarchy: Hierarchy.get_latest_attempts(latest_resource_attempt.id)
        }}}
    end
  end

  @impl Lifecycle
  def finalize(%FinalizationContext{} = _context) do
    {:error, {:unsupported}}
  end

  @impl Lifecycle
  def review(%ReviewContext{} = context) do
    Common.review(context)
  end

  @impl Lifecycle
  def start(%VisitContext{} = context) do
    Hierarchy.create(context)
  end
end
