defmodule Oli.Delivery.Attempts.PageLifecycle.Lifecycle do
  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    ReviewContext,
    FinalizationContext,
    FinalizationSummary,
    HistorySummary,
    AttemptState
  }

  @doc """
  Access or create the attempt state necessary to allow the visitation of a page.  Depending
  on the implementation, this request to visit the page may return one of the following result
  statuses:

  :not_started - There is no active attempt and one cannot be implicitly started
  :in_progress - There is an active attempt and its state is returned.  This active attempt may have
  been implicitly created, depending on the implementation
  :revised - There is an active attempt, and its state is returned, but it has been detected that
  the page revision has been changed in a publication since the starte of this attempt
  """
  @callback visit(%VisitContext{}) ::
              {:ok, {:not_started, %HistorySummary{}}}
              | {:ok, {:in_progress, %AttemptState{}}}
              | {:ok, {:revised, %AttemptState{}}}
              | {:error, String.t()}

  @doc """
  Explicitly starts a new attempt for a page. Can fail for reasons of no more attempts being available, or
  if there is already an existing attempt present.  On success, returns the tuple:

  {:ok, %AttemptState{}}
  """
  @callback start(%VisitContext{}) ::
              {:ok, %AttemptState{}}
              | {:error, {:no_more_attempts}}
              | {:error, {:active_attempt_present}}

  @doc """
  Accesses the attempt state for a particular resoure attempt. This is guaranteed not not transition
  the page in any way.

  Returns a tuple of the form:

  {:ok, {status, %AttemptState{}}}

  Where status can be `:in_progress` if the attempt is still active or `:finalized` if the attempt has
  been finalized
  """
  @callback review(%ReviewContext{}) ::
              {:ok, {:in_progress, %AttemptState{}}}
              | {:ok, {:finalized, %AttemptState{}}}

  @doc """
  Finalizes a page attempt.

  On success, returns a tuple of the form:

  {:ok, %FinalizationSummary{}}

  Can fail if the attempt is already submitted or if finalization is not supported by the implementation
  """
  @callback finalize(%FinalizationContext{}) ::
              {:ok, %FinalizationSummary{}}
              | {:error, {:already_submitted}}
              | {:error, {:unsupported}}
end
