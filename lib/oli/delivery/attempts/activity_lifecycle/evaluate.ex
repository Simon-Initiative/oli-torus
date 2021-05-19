defmodule Oli.Delivery.Attempts.ActivityLifecycle.Evaluate do
  alias Oli.Delivery.Evaluation.{Result, EvaluationContext, Standard, Adaptive}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ClientEvaluation, StudentInput}
  alias Oli.Delivery.Snapshots
  alias Oli.Delivery.Attempts.Scoring

  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities
  alias Oli.Activities.State.ActivityState
  alias Oli.Resources.{Revision}
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Part
  alias Oli.Activities.Transformers
  alias Oli.Publishing.{PublishedResource, DeliveryResolver}
  alias Oli.Delivery.Page.ModelPruner

  alias Oli.Activities.Model
  import Oli.Delivery.Attempts.Core
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence

  @doc """
  Processes a student submission for some number of parts for the given
  activity attempt guid.  If this collection of part attempts completes the activity
  the results of the part evalutions (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  There can be less items in the results list than there are items in the input part_inputs
  as logic here will not evaluate part_input instances whose part attempt has already
  been evaluated.

  On failure returns `{:error, error}`
  """
  @spec evaluate_from_input(String.t(), String.t(), [map()]) :: {:ok, [map()]} | {:error, any}
  def evaluate_from_input(section_slug, activity_attempt_guid, part_inputs) do
    Repo.transaction(fn ->
      part_attempts = get_latest_part_attempts(activity_attempt_guid)

      roll_up = fn result ->
        rollup_part_attempt_evaluations(activity_attempt_guid)
        result
      end

      no_roll_up = fn result -> result end

      {roll_up_fn, part_inputs} =
        case filter_already_submitted(part_inputs, part_attempts) do
          {true, part_inputs} -> {roll_up, part_inputs}
          {false, part_inputs} -> {no_roll_up, part_inputs}
        end

      case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
           |> persist_evaluations(part_inputs, roll_up_fn) do
        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
        _ -> Repo.rollback("unknown error")
      end
    end)
    |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)
  end

  @doc """
  Processes a preview mode evaulation.
  """
  @spec evaluate_from_preview(map(), [map()]) :: {:ok, [map()]} | {:error, any}
  def evaluate_from_preview(model, part_inputs) do
    {:ok, %Model{parts: parts}} = Model.parse(model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

    evaluations =
      Enum.map(part_inputs, fn %{part_id: part_id, input: input} ->
        part = Map.get(part_map, part_id)

        # we should eventually support test evals that can pass to the server the
        # full context, but for now we hardcode all of the context except the input
        context = %EvaluationContext{
          resource_attempt_number: 1,
          activity_attempt_number: 1,
          part_attempt_number: 1,
          input: input.input
        }

        Oli.Delivery.Evaluation.Evaluator.evaluate(part, context)
      end)
      |> Enum.map(fn e ->
        case e do
          {:ok, {feedback, result}} -> %{feedback: feedback, result: result}
          {:error, _} -> %{error: "error in evaluation"}
        end
      end)

    evaluations =
      Enum.zip(evaluations, part_inputs)
      |> Enum.map(fn {e, %{part_id: part_id}} -> Map.put(e, :part_id, part_id) end)

    {:ok, evaluations}
  end

  def evaluate_from_stored_input(activity_attempt_guid) do
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    if Enum.all?(part_attempts, fn pa -> pa.response != nil end) do
      roll_up_fn = fn result ->
        rollup_part_attempt_evaluations(activity_attempt_guid)
        result
      end

      # derive the part_attempts from the currently saved state that we expect
      # to find in the part_attempts
      part_inputs =
        Enum.map(part_attempts, fn p ->
          %{
            attempt_guid: p.attempt_guid,
            input: %StudentInput{input: Map.get(p.response, "input")}
          }
        end)

      case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
           |> persist_evaluations(part_inputs, roll_up_fn) do
        {:ok, _} -> part_attempts
        {:error, error} -> Repo.rollback(error)
      end
    else
      Repo.rollback({:not_all_answered})
    end
  end

  @doc """
  Processes a set of client evaluations for some number of parts for the given
  activity attempt guid.  If this collection of evaluations completes the activity
  the results of the part evalutions (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  On failure returns `{:error, error}`
  """
  @spec apply_client_evaluation(String.t(), String.t(), [map()]) ::
          {:ok, [map()]} | {:error, any}
  def apply_client_evaluation(section_slug, activity_attempt_guid, client_evaluations) do
    # verify this activity type allows client evaluation
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)
    activity_registration_slug = activity_attempt.revision.activity_type.slug

    part_inputs =
      Enum.map(client_evaluations, fn %{
                                        attempt_guid: attempt_guid,
                                        client_evaluation: %ClientEvaluation{input: input}
                                      } ->
        %{attempt_guid: attempt_guid, input: input}
      end)

    case Oli.Activities.get_registration_by_slug(activity_registration_slug) do
      %Oli.Activities.ActivityRegistration{allow_client_evaluation: true} ->
        Repo.transaction(fn ->
          part_attempts = get_latest_part_attempts(activity_attempt_guid)

          roll_up = fn result ->
            rollup_part_attempt_evaluations(activity_attempt_guid)
            result
          end

          no_roll_up = fn result -> result end

          {roll_up_fn, client_evaluations} =
            case filter_already_submitted(client_evaluations, part_attempts) do
              {true, client_evaluations} -> {roll_up, client_evaluations}
              {false, client_evaluations} -> {no_roll_up, client_evaluations}
            end

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
                  %Oli.Delivery.Evaluation.Actions.FeedbackActionResult{
                    type: "FeedbackActionResult",
                    attempt_guid: attempt_guid,
                    feedback: feedback,
                    score: score,
                    out_of: out_of
                  }}
               end)
               |> (fn evaluations -> {:ok, evaluations} end).()
               |> persist_evaluations(part_inputs, roll_up_fn) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
            _ -> Repo.rollback("unknown error")
          end
        end)
        |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)

      _ ->
        {:error, "Activity type does not allow client evaluation"}
    end
  end

  def rollup_part_attempt_evaluations(activity_attempt_guid) do
    # find the latest part attempts
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    # apply the scoring strategy and set the evaluation on the activity
    activity_attempt = get_activity_attempt_by(attempt_guid: activity_attempt_guid)

    %Result{score: score, out_of: out_of} =
      Scoring.calculate_score(activity_attempt.revision.scoring_strategy_id, part_attempts)

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      date_evaluated: DateTime.utc_now()
    })
  end

  # Evaluate a list of part_input submissions for a matching list of part_attempt records
  defp evaluate_submissions(_, [], _), do: {:error, "nothing to process"}

  defp evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts) do
    %ActivityAttempt{
      transformed_model: transformed_model,
      attempt_number: attempt_number,
      resource_attempt: resource_attempt
    } =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload([:resource_attempt])

    {:ok, %Model{parts: parts}} = Model.parse(transformed_model)

    # We need to tie the attempt_guid from the part_inputs to the attempt_guid
    # from the %PartAttempt, and then the part id from the %PartAttempt to the
    # part id in the parsed model.
    part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)
    attempt_map = Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

    evaluations =
      Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->
        attempt = Map.get(attempt_map, attempt_guid)
        part = Map.get(part_map, attempt.part_id)

        context = %EvaluationContext{
          resource_attempt_number: resource_attempt.attempt_number,
          activity_attempt_number: attempt_number,
          part_attempt_number: attempt.attempt_number,
          input: input.input
        }

        impl = get_eval_impl(part)
        impl.perform(attempt_guid, context, part)
      end)

    {:ok, evaluations}
  end

  defp get_eval_impl(%Part{} = part) do
    case Map.get(part, :outcomes) do
      nil -> Standard
      [] -> Standard
      _ -> Adaptive
    end
  end

  # Filters out part_inputs whose attempts are already submitted.  This step
  # simply lowers the burden on an activity client for having to manage this - as
  # they now can instead just choose to always submit all parts.  Also
  # returns a boolean indicated whether this filtered collection of submissions
  # will complete the activity attempt.
  defp filter_already_submitted(part_inputs, part_attempts) do
    # filter the part_inputs that have already been evaluated
    already_evaluated =
      Enum.filter(part_attempts, fn p -> p.date_evaluated != nil end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    part_inputs =
      Enum.filter(part_inputs, fn %{attempt_guid: attempt_guid} ->
        !MapSet.member?(already_evaluated, attempt_guid)
      end)

    # Check to see if this would complete the activity submidssion
    yet_to_be_evaluated =
      Enum.filter(part_attempts, fn p -> p.date_evaluated == nil end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    to_be_evaluated =
      Enum.map(part_inputs, fn e -> e.attempt_guid end)
      |> MapSet.new()

    {MapSet.equal?(yet_to_be_evaluated, to_be_evaluated), part_inputs}
  end
end
