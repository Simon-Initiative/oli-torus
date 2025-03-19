defmodule Oli.Delivery.Attempts.ActivityLifecycle.RollUp do

  @moduledoc """
  Handles **rollup operations** after part-level evaluations to ensure proper propagation of scores
  from part attempts up through activity attempts, resource attempts, and resource accesses.

  This module is responsible for aggregating and updating scores and lifecycle states after individual
  part attempts have been evaluated, completing the activity lifecycle and ensuring consistency across related records.

  ### Key Responsibilities:
  - Aggregate scores from individual part attempts and roll them up to the activity attempt.
  - For graded pages with score-as-you-go strategies, further roll up the results to the resource attempt and resource access levels.
  - Determine the appropriate rollup function based on evaluation context (evaluated, submitted, or no-op).
  - Update lifecycle states (e.g., marking activity attempts as `:submitted` or `:evaluated`).
  - Support multiple scoring application types, including "batch" and "score-as-you-go."

  ### Public API Functions:

  #### `determine_activity_rollup_fn/3`
  Determines and returns a function that performs the appropriate rollup action depending on the evaluation state.

  - **Params**:
    - `activity_attempt_guid`: The GUID of the activity attempt.
    - `part_inputs`: The collection of part inputs submitted.
    - `part_attempts`: The current part attempts.
  - **Behavior**: Based on the inputs and attempt states, selects one of:
    - `evaluated_fn`: Rolls up to activity and possibly resource level.
    - `submitted_fn`: Marks activity as submitted without scoring rollup.
    - `no_op_fn`: Does nothing (noop).
  - **Returns**: A zero-arity function to be executed later.

  ---

  #### `rollup_evaluated/2`
  Performs a full rollup of evaluated part attempts to their corresponding activity attempt and,
  if applicable, to the resource attempt and resource access records.

  - **Params**:
    - `activity_attempt_guid`: The GUID of the evaluated activity attempt.
    - `part_attempts`: List of part attempts used for score aggregation.
  - **Behavior**:
    - Calculates aggregate scores based on the configured scoring strategy.
    - Updates `activity_attempt`, `resource_attempt`, and `resource_access` records.
    - Supports both "batch scoring" and "score-as-you-go" workflows.
  - **Returns**: `:ok` or `:error`.

  ---

  #### `rollup_submitted/1`
  Marks an activity attempt as `:submitted` without performing score aggregation.
  """

  require Logger

  import Ecto.Query, warn: false
  import Oli.Delivery.Attempts.Core
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt, ResourceAccess}
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence
  import Oli.Delivery.Attempts.ActivityLifecycle.Utils

  alias Oli.Delivery.Evaluation.{Result}
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Repo
  alias Oli.Delivery.Attempts.Scoring

  @doc """
  Returns a function that when executed, will properly roll up the evaluated
  part attempts to (at least) the activity attempt. Depending on the context,
  this function may also roll up the results to the resource attempt and resource access.
  """
  def determine_activity_rollup_fn(
         activity_attempt_guid,
         part_inputs,
         part_attempts
       ) do
    evaluated_fn = fn result ->
      rollup_evaluated(activity_attempt_guid, part_attempts)
      result
    end

    submitted_fn = fn result ->
      rollup_submitted(activity_attempt_guid)
      result
    end

    no_op_fn = fn result -> result end

    case determine_activity_rollup_state(part_inputs, part_attempts) do
      :evaluated -> evaluated_fn
      :submitted -> submitted_fn
      :no_op -> no_op_fn
    end
  end

  @doc """
  From the update to a collection of part attempts, return a function that will properly roll
  up the score to the activity attempt, and possibly the resource attempt and resource access.

  The returned function takes zero arguments, and returns either :ok or :error.

  This function makes at most two read queries to the database.
  """
  def rollup_evaluated(activity_attempt_guid, part_attempts) do

    # First query: retrieve both the activity and resource attempt info, plus key
    # details about the page they are on
    %{
      activity_attempt_id: activity_attempt_id,
      activity_id: activity_id,
      resource_attempt_id: resource_attempt_id,
      resource_access_id: resource_access_id,
      activity_scoring_strategy_id: activity_scoring_strategy_id,
      page_scoring_strategy_id: page_scoring_strategy_id,
      graded: graded,
      batch_scoring: batch_scoring
    } = get_attempts_and_page_details(activity_attempt_guid)

    score_as_you_go? = graded and !batch_scoring

    # Record the time, so we apply it consistently to all records
    now = DateTime.utc_now()

    %Result{score: score, out_of: out_of} =
      Scoring.calculate_score(activity_scoring_strategy_id, part_attempts)

    case score_as_you_go? do

      # Second query: retrieve portions of all of the activity attempts for this
      # activity on this page - and the latest attempts for other
      # activities on this page
      true ->

        relevant_activity_attempts = get_relevant_activity_attempts(resource_attempt_id, activity_id)

        # Here we calculate the "aggregate" score for this activity across all of its attempts
        other_attempts_for_this_activity = Enum.filter(relevant_activity_attempts, fn a ->
          a.resource_id == activity_id and a.attempt_guid != activity_attempt_guid
        end)


        all_attempts = [%{score: score, out_of: out_of, date_evaluated: now} | other_attempts_for_this_activity]

        %Result{score: aggregate_score, out_of: aggregate_out_of} =
          Scoring.calculate_score(page_scoring_strategy_id, all_attempts)

        # Now we calculate page attempt score - across the aggregate scores of all other
        # activities on this page and the one that we just calculated

        attempts_for_other_activities = Enum.filter(relevant_activity_attempts, fn a ->
          a.resource_id != activity_id
        end)

        all_aggregate_attempts = [%{aggregate_score: aggregate_score, aggregate_out_of: aggregate_out_of, date_evaluated: now} | attempts_for_other_activities]
        |> Enum.map(fn a ->
          %{score: a.aggregate_score, out_of: a.aggregate_out_of, date_evaluated: a.date_evaluated}
        end)

        total_scoring_strategy_id = Oli.Resources.ScoringStrategy.get_id_by_type("total")
        %Result{score: page_score, out_of: page_out_of} = Scoring.calculate_score(total_scoring_strategy_id, all_aggregate_attempts)

        with {1, _} <- update_resource_access(resource_access_id, %{score: page_score, out_of: page_out_of}, now),
          {1, _} <- update_resource_attempt(resource_attempt_id, %{score: page_score, out_of: page_score}, now),
          {1, _} <- update_activity_attempt(activity_attempt_id, %{score: score, out_of: out_of, aggregate_score: aggregate_score, aggregate_out_of: aggregate_out_of}, now) do
          :ok
        else
          _ -> :error
        end

      false ->
        case update_activity_attempt(activity_attempt_id, %{score: score, out_of: out_of}, now) do
          {1, _} -> :ok
          _ -> :error
        end
    end

  end

  @doc """
  Rollup the submitted state of an activity attempt.
  """
  def rollup_submitted(activity_attempt_guid) do
    get_activity_attempt_by(attempt_guid: activity_attempt_guid)
    |> update_activity_attempt(%{
      lifecycle_state: :submitted,
      date_submitted: DateTime.utc_now()
    })
  end

  @doc """
  For a given resource attempt, roll up the scores from all part attempts
  to all "active" activity attempts.
  """
  def rollup_all(
        resource_attempt,
        datashop_session_id,
        effective_settings
      ) do
    activity_attempts =
      case resource_attempt.revision do
        %{content: %{"advancedDelivery" => true}} ->
          get_latest_non_active_activity_attempts(resource_attempt.id)

        _ ->
          get_latest_activity_attempts(resource_attempt.id)
      end

    Enum.reduce_while(
      activity_attempts,
      {0, [], [], []},
      fn activity_attempt,
         {
           i,
           activity_attempt_values,
           activity_attempt_params,
           part_attempt_guids
         } = acc ->
        if activity_attempt.lifecycle_state != :evaluated and activity_attempt.scoreable do
          activity_attempt = Map.put(activity_attempt, :resource_attempt, resource_attempt)

          case update_part_attempts_for_activity(
                 activity_attempt,
                 datashop_session_id,
                 effective_settings
               ) do
            {:ok, part_inputs} ->
              part_attempts = get_latest_part_attempts(activity_attempt.attempt_guid)

              %{
                score: score,
                out_of: out_of,
                lifecycle_state: lifecycle_state,
                date_evaluated: date_evaluated,
                date_submitted: date_submitted
              } = determine_activity_rollup_attrs(part_inputs, part_attempts, activity_attempt)

              {:cont,
               {
                 i + 6,
                 activity_attempt_values ++
                   [
                     "($#{i + 1}, $#{i + 2}::double precision, $#{i + 3}::double precision, $#{i + 4}, $#{i + 5}::timestamp, $#{i + 6}::timestamp)"
                   ],
                 activity_attempt_params ++
                   [
                     activity_attempt.attempt_guid,
                     score,
                     out_of,
                     Atom.to_string(lifecycle_state),
                     date_evaluated,
                     date_submitted
                   ],
                 part_attempt_guids ++
                   Enum.map(part_attempts, fn part_attempt -> part_attempt.attempt_guid end)
               }}

            error ->
              {:halt, error}
          end
        else
          {:cont, acc}
        end
      end
    )
  end

  defp update_part_attempts_for_activity(activity_attempt, datashop_session_id, effective_settings) do
    part_attempts = get_latest_part_attempts(activity_attempt.attempt_guid)

    part_inputs =
      part_attempts
      |> Enum.map(fn pa ->
        {input, files} =
          if pa.response,
            do: {Map.get(pa.response, "input"), Map.get(pa.response, "files", [])},
            else: {nil, nil}

        %{
          attempt_guid: pa.attempt_guid,
          input: %StudentInput{input: input, files: files}
        }
      end)
      |> filter_already_evaluated(part_attempts)

    case activity_attempt
         |> do_evaluate_submissions(part_inputs, part_attempts, effective_settings)
         |> persist_evaluations(part_inputs, fn result -> result end, datashop_session_id) do
      {:ok, _} -> {:ok, part_inputs}
      e -> e
    end
  end


  defp update_resource_access(resource_access_id, attrs, now) do

    attrs = Map.merge(attrs, %{updated_at: now})
    keyword_list = attrs |> Map.to_list()

    from(a in ResourceAccess,
      where: a.id == ^resource_access_id,
      update: [set: ^keyword_list]
    )
    |> Repo.update_all([])

  end

  defp update_resource_attempt(resource_attempt_id, attrs, now) do

    attrs = Map.merge(attrs, %{updated_at: now})
    keyword_list = attrs |> Map.to_list()

    from(a in ResourceAttempt,
      where: a.id == ^resource_attempt_id,
      update: [set: ^keyword_list]
    )
    |> Repo.update_all([])
  end

  defp update_activity_attempt(activity_attempt_id, attrs, now) do

    attrs = Map.merge(attrs, %{lifecycle_state: :evaluated, date_evaluated: now, date_submitted: now, updated_at: now})

    keyword_list = attrs |> Map.to_list()

    from(a in ActivityAttempt,
      where: a.id == ^activity_attempt_id,
      update: [set: ^keyword_list]
    )
    |> Repo.update_all([])

  end

  defp get_attempts_and_page_details(activity_attempt_guid) do

    from(
      a in ActivityAttempt,
      join: ra in ResourceAttempt, on: a.resource_attempt_id == ra.id,
      join: rev in Revision, on: rev.id == a.revision_id,
      join: rev2 in Revision, on: rev2.id == ra.revision_id,
      where: a.attempt_guid == ^activity_attempt_guid,
      select: %{
        activity_attempt_id: a.id,
        resource_attempt_id: ra.id,
        activity_id: a.resource_id,
        resource_access_id: ra.resource_access_id,
        activity_scoring_strategy_id: rev.scoring_strategy_id,
        graded: rev2.graded,
        page_scoring_strategy_id: rev2.scoring_strategy_id,
        batch_scoring: rev2.batch_scoring
      }
    )
    |> Repo.one()
  end

  defp get_relevant_activity_attempts(resource_attempt_id, current_activity_id) do

    Repo.all(
      from(aa in ActivityAttempt,
        left_join: aa2 in ActivityAttempt,
        on:
          aa.resource_attempt_id == aa2.resource_attempt_id and aa.resource_id == aa2.resource_id and
            aa.id < aa2.id,
        where: aa.resource_attempt_id == ^resource_attempt_id and (is_nil(aa2) or aa.resource_id == ^current_activity_id),
        select: %{
          resource_id: aa.resource_id,
          score: aa.score,
          out_of: aa.out_of,
          aggregate_score: aa.aggregate_score,
          aggregate_out_of: aa.aggregate_out_of,
          date_evaluated: aa.date_evaluated
        }
      )
    )

  end


  defp determine_activity_rollup_attrs(part_inputs, part_attempts, activity_attempt) do
    case determine_activity_rollup_state(part_inputs, part_attempts) do
      :evaluated ->
        %Result{score: score, out_of: out_of} =
          Scoring.calculate_score(activity_attempt.revision.scoring_strategy_id, part_attempts)

        %{
          score: score,
          out_of: out_of,
          lifecycle_state: :evaluated,
          date_evaluated: DateTime.utc_now(),
          date_submitted: DateTime.utc_now()
        }

      :submitted ->
        %{
          score: nil,
          out_of: nil,
          lifecycle_state: :submitted,
          date_evaluated: nil,
          date_submitted: DateTime.utc_now()
        }

      :no_op ->
        activity_attempt
    end
  end

  defp determine_activity_rollup_state(part_inputs, part_attempts) do
    count_if = fn attempts, type ->
      Enum.reduce(attempts, 0, fn a, c ->
        if a.lifecycle_state == type do
          c + 1
        else
          c
        end
      end)
    end

    part_attempts_map =
      Enum.reduce(part_attempts, %{}, fn pa, m -> Map.put(m, pa.attempt_guid, pa) end)

    part_attempts =
      Enum.reduce(part_inputs, part_attempts_map, fn part_input, map ->
        pa = Map.get(map, part_input.attempt_guid)

        unless is_nil(pa) do
          if (pa.lifecycle_state == :submitted or pa.lifecycle_state == :active) and
               pa.grading_approach == :automatic do
            Map.put(map, pa.attempt_guid, %{pa | lifecycle_state: :evaluated})
          else
            if (pa.lifecycle_state == :submitted or pa.lifecycle_state == :active) and
                 pa.grading_approach == :manual do
              Map.put(map, pa.attempt_guid, %{pa | lifecycle_state: :submitted})
            else
              map
            end
          end
        else
          Logger.info(
            "Part attempt with GUID #{part_input.attempt_guid} was not found in part attempts map"
          )

          map
        end
      end)
      |> Map.values()

    case {count_if.(part_attempts, :evaluated), count_if.(part_attempts, :submitted),
          count_if.(part_attempts, :active)} do
      {_, 0, 0} -> :evaluated
      {_, _, 0} -> :submitted
      {_, _, _} -> :no_op
    end
  end

end
