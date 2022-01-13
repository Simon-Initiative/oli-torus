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

  alias Oli.Delivery.Attempts.Scoring
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Delivery.Evaluation.Result
  alias Oli.Delivery.Attempts.PageLifecycle.Common
  alias Oli.Delivery.Attempts.Core.ResourceAccess
  import Oli.Delivery.Attempts.Core

  @moduledoc """
  Implementation of a page Lifecycle behaviour for graded pages.
  """

  @behaviour Lifecycle

  @impl Lifecycle
  def visit(%VisitContext{
        latest_resource_attempt: latest_resource_attempt,
        page_revision: page_revision,
        section_slug: section_slug,
        user_id: user_id
      }) do
    # There is no "active" attempt if there has never been an attempt or if the latest
    # attempt has been finalized.
    if is_nil(latest_resource_attempt) or !is_nil(latest_resource_attempt.date_evaluated) do
      # Graded pages must be started explicitly by the student, giving them to chance to
      # see how many attempts, etc.

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
        {:ok, resource_attempt} = Hierarchy.create(context)
        AttemptState.fetch_attempt_state(resource_attempt, page_revision)

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
          # submission.  so we only submit those that are still yet to be finalized, and
          # that are scoreable
          if a.date_evaluated == nil and a.scoreable do
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
    # fetch the resource attempt, with the pinned revision preloaded
    resource_attempt = get_resource_attempt_by(attempt_guid: resource_attempt_guid)

    if resource_attempt.date_evaluated == nil do
      # Only considering 'scoreable' attempts, add up, adjust and validate the
      # 'grade' which consists of a tuple of {score, out_of}
      {score, out_of} =
        resource_attempt.activity_attempts
        |> Enum.filter(fn activity_attempt -> activity_attempt.scoreable end)
        |> Enum.reduce({0, 0}, &aggregation_reducer/2)
        |> override_out_of(resource_attempt.revision.content)
        |> ensure_valid_grade

      update_resource_attempt(resource_attempt, %{
        score: score,
        out_of: out_of,
        date_evaluated: DateTime.utc_now()
      })
    else
      {:error, {:already_submitted}}
    end
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

  defp roll_up_resource_attempts_to_access(section_slug, resource_access_id) do
    access = Oli.Repo.get(ResourceAccess, resource_access_id)
    graded_attempts = get_graded_attempts_from_access(access.id)

    %{scoring_strategy_id: strategy_id} =
      DeliveryResolver.from_resource_id(section_slug, access.resource_id)

    {score, out_of} =
      Scoring.calculate_score(strategy_id, graded_attempts)
      |> ensure_valid_grade()

    update_resource_access(access, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end
end
