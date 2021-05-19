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

  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Evaluation.Result
  alias Oli.Delivery.Attempts.PageLifecycle.Common
  import Oli.Delivery.Attempts.Core

  @behaviour Lifecycle

  @impl Lifecycle
  def visit(%VisitContext{
        latest_resource_attempt: latest_resource_attempt,
        page_revision: page_revision,
        section_slug: section_slug,
        user_id: user_id
      }) do
    if is_nil(latest_resource_attempt) or !is_nil(latest_resource_attempt.date_evaluated) do
      {access, attempts} =
        get_resource_attempt_history(page_revision.resource_id, section_slug, user_id)

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
      if page_revision.id !== latest_resource_attempt.revision_id do
        {:ok,
         {:revised,
          %AttemptState{
            resource_attempt: latest_resource_attempt,
            attempt_hierarchy: Hierarchy.get_latest_attempts(latest_resource_attempt.id)
          }}}
      else
        {:ok,
         {:in_progress,
          %AttemptState{
            resource_attempt: latest_resource_attempt,
            attempt_hierarchy: Hierarchy.get_latest_attempts(latest_resource_attempt.id)
          }}}
      end
    end
  end

  @impl Lifecycle
  def start(
        %VisitContext{
          page_revision: page_revision,
          section_slug: section_slug,
          user_id: user_id
        } = context
      ) do
    {_, resource_attempts} =
      get_resource_attempt_history(page_revision.resource_id, section_slug, user_id)

    # We want to disregard any attempts that pertained to revisions whose graded status
    # do not match the current graded status. This acommodates the toggling of "graded" status
    # across publications, interwoven with student attempts, to work correctly
    resource_attempts =
      Enum.filter(resource_attempts, fn a -> a.revision.graded == page_revision.graded end)

    case {page_revision.max_attempts > length(resource_attempts) or
            page_revision.max_attempts == 0, has_any_active_attempts?(resource_attempts)} do
      {true, false} ->
        Hierarchy.create(context)

      {true, true} ->
        {:error, {:active_attempt_present}}

      {false, _} ->
        {:error, {:no_more_attempts}}
    end
  end

  @impl Lifecycle
  def review(%ReviewContext{} = context) do
    Common.review(context)
  end

  @impl Lifecycle
  def finalize(%FinalizationContext{
        resource_attempt: resource_attempt,
        section_slug: section_slug
      }) do
    if resource_attempt.date_evaluated == nil do
      # Collect all of the part attempt guids for all of the activities that
      # get finalized
      part_attempt_guids =
        Enum.map(resource_attempt.activity_attempts, fn a ->
          # some activities will finalize themselves ahead of a graded page
          # submission.  so we only submit those that are still yet to be finalized.
          if a.date_evaluated == nil do
            Evaluate.evaluate_from_stored_input(a.attempt_guid)
          else
            []
          end
        end)
        |> List.flatten()
        |> Enum.map(fn part_attempt -> part_attempt.attempt_guid end)

      case roll_up_activities_to_resource_attempt(resource_attempt.attempt_guid) do
        {:ok, _} ->
          case roll_up_resource_attempts_to_access(
                 section_slug,
                 resource_attempt.resource_access_id
               ) do
            {:ok, resource_access} ->
              {:ok,
               %FinalizationSummary{
                 resource_access: resource_access,
                 part_attempt_guids: part_attempt_guids
               }}

            e ->
              e
          end

        e ->
          e
      end
    else
      {:error, {:already_submitted}}
    end
  end

  defp roll_up_activities_to_resource_attempt(resource_attempt_guid) do
    resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

    if resource_attempt.date_evaluated == nil do
      # Leaving this hardcoded to 'total' seems to make sense, but perhaps in the
      # future we do allow this to be configured
      {score, out_of} =
        Enum.reduce(resource_attempt.activity_attempts, {0, 0}, fn p, {score, out_of} ->
          {score + p.score, out_of + p.out_of}
        end)

      update_resource_attempt(resource_attempt, %{
        score: score,
        out_of: out_of,
        date_evaluated: DateTime.utc_now()
      })
    else
      {:error, {:already_submitted}}
    end
  end

  defp roll_up_resource_attempts_to_access(section_slug, resource_access_id) do
    access = Oli.Repo.get(ResourceAccess, resource_access_id)
    graded_attempts = get_graded_attempts_from_access(access.id)

    %{scoring_strategy_id: strategy_id} =
      DeliveryResolver.from_resource_id(section_slug, access.resource_id)

    %Result{score: score, out_of: out_of} = Scoring.calculate_score(strategy_id, graded_attempts)

    update_resource_access(access, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end
end
