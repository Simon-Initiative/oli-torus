defmodule Oli.Delivery.Attempts.ActivityLifecycle.ApplyClientEvaluation do
  @moduledoc """
  Applies client-provided evaluation results to part attempts and runs the standard
  pipeline (rollup, metrics, snapshots, xAPI/log). Used by Evaluate (e.g. rules engine)
  and by activity-type-specific modules (e.g. DirectedDiscussion) so they do not
  depend on Evaluate.
  """

  require Logger

  import Oli.Delivery.Attempts.Core
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence
  import Oli.Delivery.Attempts.ActivityLifecycle.Utils

  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.ClientEvaluation
  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp
  alias Oli.Delivery.Snapshots
  alias Oli.Delivery.Experiments.LogWorker

  @doc """
  Processes a set of client evaluations for some number of parts for the given
  activity attempt guid.  If this collection of evaluations completes the activity
  the results of the part evaluations (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  The optional "normalize_mode" takes values of :normalize or :do_not_normalize.  The default
  :normalize mode will normalize the part based score and out_of to a range of 0 to 1.
  This ensures for all basic page based assessments that every activity has equal weight.

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  On failure returns `{:error, error}`

  ## Options
  - `:part_attempts_input` - Pre-fetched part attempts (optional).
  - `:use_fixed_score` - `{score, out_of}` to force a fixed score on rollup.
  - `:no_roll_up` - Set to true to disable rollup after part evaluation.
  - `:enforce_client_side_eval` - If true (default), activity type must allow client evaluation.
  """
  def apply(
        section_slug,
        activity_attempt_guid,
        client_evaluations,
        datashop_session_id,
        opts \\ []
      ) do
    part_attempts_input = Keyword.get(opts, :part_attempts_input, nil)
    use_fixed_score = Keyword.get(opts, :use_fixed_score, nil)
    no_roll_up = Keyword.get(opts, :no_roll_up, false)
    enforce_client_side_eval = Keyword.get(opts, :enforce_client_side_eval, true)

    activity_attempt =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload(revision: [:activity_type])

    activity_registration_slug = activity_attempt.revision.activity_type.slug

    part_inputs =
      Enum.map(client_evaluations, fn %{
                                        attempt_guid: attempt_guid,
                                        client_evaluation: %ClientEvaluation{
                                          input: input,
                                          timestamp: timestamp
                                        }
                                      } ->
        %{attempt_guid: attempt_guid, input: input, timestamp: timestamp}
      end)

    %Oli.Activities.ActivityRegistration{allow_client_evaluation: allow_client_evaluation} =
      Oli.Activities.get_registration_by_slug(activity_registration_slug)

    if not enforce_client_side_eval or allow_client_evaluation do
      Repo.transaction(fn ->
        part_attempts = part_attempts_input || get_latest_part_attempts(activity_attempt_guid)
        part_inputs = filter_already_evaluated(part_inputs, part_attempts)

        roll_up_fn =
          case use_fixed_score do
            nil ->
              RollUp.determine_activity_rollup_fn(
                activity_attempt_guid,
                part_inputs,
                part_attempts
              )

            {score, out_of} ->
              fn result ->
                evaluate_with_rule_engine_score(activity_attempt_guid, score, out_of)
                result
              end
          end

        roll_up_fn =
          if no_roll_up do
            fn result -> result end
          else
            roll_up_fn
          end

        result =
          persist_client_evaluations(
            part_inputs,
            client_evaluations,
            roll_up_fn,
            false,
            datashop_session_id
          )

        Oli.Delivery.Metrics.update_page_progress(activity_attempt_guid)

        result
      end)
      |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)
      |> LogWorker.maybe_schedule(activity_attempt_guid, section_slug)
    else
      {:error, "Activity type does not allow client evaluation"}
    end
  end

  defp persist_client_evaluations(
         part_inputs,
         client_evaluations,
         roll_up_fn,
         _,
         datashop_session_id
       ) do
    case client_evaluations
         |> Enum.map(fn %{
                          attempt_guid: attempt_guid,
                          client_evaluation: %ClientEvaluation{
                            score: score,
                            out_of: out_of,
                            feedback: feedback
                          }
                        } ->
           {:ok,
            %Oli.Delivery.Evaluation.Actions.FeedbackAction{
              type: "FeedbackAction",
              attempt_guid: attempt_guid,
              feedback: feedback,
              score: score,
              out_of: out_of
            }}
         end)
         |> (fn evaluations -> {:ok, evaluations} end).()
         |> persist_evaluations(part_inputs, roll_up_fn, datashop_session_id) do
      {:ok, results} ->
        results

      {:error, error} ->
        Oli.Utils.log_error("error inside apply_client_evaluation", error)
        Repo.rollback(error)

      _ ->
        Repo.rollback("unknown error")
    end
  end

  defp evaluate_with_rule_engine_score(activity_attempt_guid, score, out_of) do
    Logger.debug("evaluate_with_rule_engine_score: score: #{score}, out_of: #{out_of}")

    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    now = DateTime.utc_now()

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      lifecycle_state: :evaluated,
      date_evaluated: now,
      date_submitted: now
    })
  end
end
