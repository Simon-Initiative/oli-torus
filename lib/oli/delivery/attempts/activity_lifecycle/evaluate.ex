defmodule Oli.Delivery.Attempts.ActivityLifecycle.Evaluate do
  alias Oli.Repo
  alias Oli.Delivery.Evaluation.{Result, EvaluationContext, Standard, Adaptive}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ClientEvaluation, StudentInput}
  alias Oli.Delivery.Snapshots
  alias Oli.Delivery.Attempts.Scoring

  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Part

  alias Oli.Activities.Model
  import Oli.Delivery.Attempts.Core
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence

  require Logger

  def evaluate_activity(section_slug, activity_attempt_guid, part_inputs) do
    %ActivityAttempt{
      transformed_model: transformed_model,
      resource_attempt: resource_attempt,
      attempt_number: attempt_number
    } =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload([:resource_attempt])

    case Model.parse(transformed_model) do
      {:ok, %Model{rules: []}} ->
        evaluate_from_input(section_slug, activity_attempt_guid, part_inputs)

      {:ok, %Model{rules: rules, delivery: delivery}} ->
        custom = Map.get(delivery, "custom", %{})

        scoringContext = %{
          maxScore: Map.get(custom, "maxScore", 0),
          maxAttempt: Map.get(custom, "maxAttempt", 1),
          trapStateScoreScheme: Map.get(custom, "trapStateScoreScheme", false),
          negativeScoreAllowed: Map.get(custom, "negativeScoreAllowed", false),
          currentAttemptNumber: attempt_number
        }

        # Logger.debug("SCORE CONTEXT: #{Jason.encode!(scoringContext)}")
        evaluate_from_rules(
          section_slug,
          resource_attempt,
          activity_attempt_guid,
          part_inputs,
          scoringContext,
          rules
        )

      e ->
        e
    end
  end

  def evaluate_from_rules(
        section_slug,
        resource_attempt,
        activity_attempt_guid,
        part_inputs,
        scoringContext,
        rules
      ) do
    state = assemble_full_adaptive_state(resource_attempt, part_inputs)

    encodeResults = true

    case NodeJS.call({"rules", :check}, [state, rules, scoringContext, encodeResults]) do
      {:ok, check_results} ->
        # Logger.debug("Check RESULTS: #{check_results}")
        decoded = Base.decode64!(check_results)
        # Logger.debug("Decoded: #{decoded}")
        decodedResults = Poison.decode!(decoded)
        dbg = decodedResults["debug"]
        Logger.debug("Results #{Jason.encode!(dbg)}")

        score = decodedResults["score"]
        out_of = decodedResults["out_of"]
        client_evaluations = to_client_results(score, out_of, part_inputs)
        Logger.debug("EV: #{Jason.encode!(client_evaluations)}")

        case apply_client_evaluation(section_slug, activity_attempt_guid, client_evaluations) do
          {:ok, _} -> {:ok, decodedResults}
          {:error, err} ->
            Logger.debug("Error in apply client results! #{err}")
            {:error, err}
        end

      e ->
        e
    end
  end

  defp to_client_results(score, out_of, part_inputs) do
    Enum.map(part_inputs, fn part_input ->
      %{
        attempt_guid: part_input.attempt_guid,
        client_evaluation: %ClientEvaluation{
          input: part_input.input.input,
          score: score,
          out_of: out_of,
          feedback: nil
        }
      }
    end)
  end

  defp assemble_full_adaptive_state(resource_attempt, part_inputs) do
    extrinsic_state = resource_attempt.state

    # need to get *all* of the activity attempts state (part responses saved thus far)
    attempt_hierarchy =
      Oli.Delivery.Attempts.PageLifecycle.Hierarchy.get_latest_attempts(resource_attempt.id)

    response_state =
      Enum.reduce(Map.values(attempt_hierarchy), %{}, fn {_activity_attempt, part_attempts}, m ->
        part_responses =
          Enum.reduce(Map.values(part_attempts), %{}, fn pa, acc ->
            case pa.response do
              "" ->
                acc

              nil ->
                acc

              _ ->
                part_values =
                  Enum.reduce(Map.values(pa.response), %{}, fn pv, acc1 ->
                    case pv do
                      nil -> acc1
                      "" -> acc1
                      _ -> Map.put(acc1, Map.get(pv, "path"), Map.get(pv, "value"))
                    end
                  end)

                Map.merge(acc, part_values)
            end
          end)

        Map.merge(m, part_responses)
      end)

    # need to combine with part_inputs as latest
    input_state =
      Enum.reduce(part_inputs, %{}, fn pi, acc ->
        case pi.input.input do
          "" ->
            acc

          nil ->
            acc

          _ ->
            inputs =
              Enum.reduce(Map.values(pi.input.input), %{}, fn input, acc1 ->
                case input do
                  nil ->
                    acc1

                  "" ->
                    acc1

                  _ ->
                    if !Map.has_key?(input, "path") do
                      acc1
                    else
                      path = Map.get(input, "path")
                      # part_inputs are assumed to be from the current activity only
                      # so we strip out the sequence id from the path to get our "local"
                      # values for the rules
                      local_path = Enum.at(Enum.take(String.split(path, "|"), -1), 0, path)
                      value = Map.get(input, "value")
                      Map.put(acc1, local_path, value)
                    end
                end
              end)

            Map.merge(acc, inputs)
        end
      end)

    attempt_state = Map.merge(response_state, extrinsic_state)
    Map.merge(input_state, attempt_state)
  end

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
  Processes a preview mode, or test, evaulation.
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

  @doc """
  Evaluates an activity attempt using only the already stored state present in
  the child part attempts.  This exists primarly to allow graded pages to
  submit all of the contained activites when the student clicks "Submit Assessment".
  """
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
