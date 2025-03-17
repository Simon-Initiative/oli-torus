defmodule Oli.Delivery.Attempts.ActivityLifecycle.Evaluate do

  import Oli.Delivery.Attempts.Core
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence

  require Logger

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Evaluation.{Result, EvaluationContext, Standard}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ClientEvaluation, StudentInput}
  alias Oli.Delivery.Snapshots
  alias Oli.Delivery.Attempts.Scoring
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model
  alias Oli.Delivery.Evaluation.Explanation
  alias Oli.Delivery.Evaluation.ExplanationContext
  alias Oli.Delivery.Experiments.LogWorker
  alias Oli.Resources.ScoringStrategy

  def evaluate_activity(section_slug, activity_attempt_guid, part_inputs, datashop_session_id) do
    activity_attempt =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload([:resource_attempt])

    %ActivityAttempt{
      resource_attempt: resource_attempt,
      attempt_number: attempt_number
    } = activity_attempt

    activity_model = select_model(activity_attempt)
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    case Model.parse(activity_model) do
      {:ok, %Model{rules: []}} ->
        evaluate_from_input(
          section_slug,
          activity_attempt_guid,
          part_inputs,
          datashop_session_id,
          part_attempts
        )

      {:ok, %Model{rules: rules, delivery: delivery, authoring: authoring}} ->
        part_attempts_submitted = submit_active_part_attempts(part_attempts)

        custom = Map.get(delivery, "custom", %{})

        is_manually_graded =
          Enum.any?(part_attempts, fn pa -> pa.grading_approach == :manual end)

        # count the manual max score, and use that as the default instead of zero if there is no maxScore set by the author
        max_score =
          case is_manually_graded do
            true ->
              manual_max = Enum.reduce(part_attempts, fn sum, pa -> sum + pa.out_of end)
              Map.get(custom, "maxScore", manual_max)

            false ->
              Map.get(custom, "maxScore", 0)
          end

        scoringContext = %{
          maxScore: max_score,
          maxAttempt: Map.get(custom, "maxAttempt", 1),
          trapStateScoreScheme: Map.get(custom, "trapStateScoreScheme", false),
          negativeScoreAllowed: Map.get(custom, "negativeScoreAllowed", false),
          currentAttemptNumber: attempt_number,
          isManuallyGraded: is_manually_graded
        }

        activitiesRequiredForEvaluation =
          Map.get(authoring, "activitiesRequiredForEvaluation", [])

        # Logger.debug("ACTIVITIES REQUIRED: #{activitiesRequiredForEvaluation}")

        variablesRequiredForEvaluation =
          Map.get(authoring, "variablesRequiredForEvaluation", nil)

        # Logger.debug("VARIABLES REQUIRED: #{Jason.encode!(variablesRequiredForEvaluation)}")

        Logger.debug("SCORE CONTEXT: #{Jason.encode!(scoringContext)}")

        evaluate_from_rules(
          section_slug,
          resource_attempt,
          activity_attempt_guid,
          part_inputs,
          scoringContext,
          rules,
          activitiesRequiredForEvaluation,
          variablesRequiredForEvaluation,
          datashop_session_id,
          part_attempts_submitted
        )

      e ->
        e
    end
  end

  defp submit_active_part_attempts(part_attempts) do
    now = Timex.now()

    part_attempts
    |> Enum.filter(fn pa -> pa.lifecycle_state == :active end)
    |> Enum.map(fn pa ->
      %{pa | lifecycle_state: :submitted, date_submitted: now, updated_at: now}
    end)
  end

  def evaluate_from_rules(
        section_slug,
        resource_attempt,
        activity_attempt_guid,
        part_inputs,
        scoringContext,
        rules,
        activitiesRequiredForEvaluation,
        variablesRequiredForEvaluation,
        datashop_session_id,
        part_attempts
      ) do
    state =
      case variablesRequiredForEvaluation do
        nil ->
          assemble_full_adaptive_state(
            resource_attempt,
            activitiesRequiredForEvaluation,
            part_inputs
          )

        _ ->
          assemble_full_adaptive_state(
            resource_attempt,
            activitiesRequiredForEvaluation,
            part_inputs
          )
          |> Map.take(variablesRequiredForEvaluation)
      end

    case Oli.Delivery.Attempts.ActivityLifecycle.RuleEvaluator.do_eval(
           state,
           rules,
           scoringContext
         ) do
      {:ok, decodedResults} ->
        score = decodedResults["score"]
        out_of = decodedResults["out_of"]
        Logger.debug("Score: #{score}")
        Logger.debug("Out of: #{out_of}")

        client_evaluations = to_client_results(score, out_of, part_inputs)

        if scoringContext.isManuallyGraded do
          case get_activity_attempt_by(attempt_guid: activity_attempt_guid) do
            nil ->
              Logger.error("Could not find activity attempt for guid: #{activity_attempt_guid}")

            activity_attempt ->
              # we need to mark the all manually scored part attempts still active to be "submitted", as
              # as marking the entire activity attempt as being submitted.
              submission_update = %{
                lifecycle_state: :submitted,
                date_submitted: DateTime.utc_now()
              }

              get_latest_part_attempts(activity_attempt.attempt_guid)
              |> Enum.filter(fn pa ->
                pa.grading_approach == :manual and pa.lifecycle_state == :active
              end)
              |> Enum.each(fn pa -> update_part_attempt(pa, submission_update) end)

              update_activity_attempt(activity_attempt, submission_update)
          end

          {:ok, decodedResults}
        else
          case apply_client_evaluation(
                 section_slug,
                 activity_attempt_guid,
                 client_evaluations,
                 datashop_session_id,
                 [part_attempts: part_attempts, use_fixed_score: {score, out_of}]
               ) do
            {:ok, _} ->
              Oli.Delivery.Attempts.PageLifecycle.Broadcaster.broadcast_attempt_updated(
                resource_attempt.attempt_guid,
                activity_attempt_guid,
                :updated
              )

              {:ok, decodedResults}

            {:error, err} ->
              Logger.error(
                "Error in apply client results from within rule evaluation! activity_guid: #{activity_attempt_guid}, evals: #{Kernel.to_string(client_evaluations)}, #{err}"
              )

              {:error, err}
          end
        end

      {:error, err} ->
        Logger.error("Error in rule evaluation! #{err}")
        {:error, err}
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

  defp assemble_full_adaptive_state(
         resource_attempt,
         activities_required_for_evaluation,
         part_inputs
       ) do
    extrinsic_state = resource_attempt.state

    # if activitiesRequiredForEvaluation is empty, we don't need to get any extra state
    response_state =
      case activities_required_for_evaluation do
        [] ->
          %{}

        _ ->
          # need to get *all* of the activity attempts state (part responses saved thus far)

          attempt_hierarchy =
            Oli.Delivery.Attempts.PageLifecycle.Hierarchy.get_latest_attempts(
              resource_attempt.id,
              activities_required_for_evaluation
            )

          Enum.reduce(Map.values(attempt_hierarchy), %{}, fn {_activity_attempt, part_attempts},
                                                             m ->
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
      end

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
                      # might look like this "q:1465253111364:752|stage.dragdrop.Drag and Drop.Body Fossil | Direct Evidence.Count"
                      path_parts = String.split(path, "|stage")
                      path_interested = List.last(path_parts)

                      local_path =
                        if String.starts_with?(path_interested, ".") do
                          "stage" <> path_interested
                        else
                          path_interested
                        end

                      value = Map.get(input, "value")
                      Map.put(acc1, local_path, value)
                    end
                end
              end)

            Map.merge(acc, inputs)
        end
      end)

    # Logger.debug("Extrinsic state: #{Jason.encode!(extrinsic_state)}")
    # Logger.debug("Response state: #{Jason.encode!(response_state)}")
    # Logger.debug("Input state: #{Jason.encode!(input_state)}")

    attempt_state = Map.merge(response_state, extrinsic_state)
    Map.merge(input_state, attempt_state)
  end

  @doc """
  Processes a student submission for some number of parts for the given
  activity attempt guid.  If this collection of part attempts completes the activity
  the results of the part evaluations (including ones already having been evaluated)
  will be rolled up to the activity attempt record.

  On success returns an `{:ok, results}` tuple where results in an array of maps. Each
  map instance contains the result of one of the evaluations in the form:

  `${score: score, out_of: out_of, feedback: feedback, attempt_guid, attempt_guid}`

  There can be less items in the results list than there are items in the input part_inputs
  as logic here will not evaluate part_input instances whose part attempt has already
  been evaluated.

  On failure returns `{:error, error}`
  """
  @spec evaluate_from_input(String.t(), String.t(), [map()], String.t()) ::
          {:ok, [map()]} | {:error, any}
  def evaluate_from_input(section_slug, activity_attempt_guid, part_inputs, datashop_session_id, part_attempts \\ nil) do
    Repo.transaction(fn ->

      part_attempts = case part_attempts do
        nil -> get_latest_part_attempts(activity_attempt_guid)
        _ -> part_attempts
      end

      part_inputs = filter_already_evaluated(part_inputs, part_attempts)

      roll_up_fn = determine_activity_rollup_fn(activity_attempt_guid, part_inputs, part_attempts)

      result =
        case evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts)
             |> persist_evaluations(part_inputs, roll_up_fn, datashop_session_id) do
          {:ok, results} -> results
          {:error, error} -> Repo.rollback(error)
          _ -> Repo.rollback("unknown error")
        end

      Oli.Delivery.Metrics.update_page_progress(activity_attempt_guid)
      result
    end)
    |> Snapshots.maybe_create_snapshot(part_inputs, section_slug)
    |> LogWorker.maybe_schedule(activity_attempt_guid, section_slug)
  end

  @doc """
  Processes a preview mode or test evaluation.
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
          page_id: 1,
          activity_attempt_guid: "test",
          part_attempt_guid: part_id,
          input: input.input
        }

        Oli.Delivery.Evaluation.Evaluator.evaluate(part, context)
      end)
      |> Enum.map(fn e ->
        case e do
          {:ok, result} -> result
          {:error, _} -> %{error: "error in evaluation"}
        end
      end)

    evaluations =
      Enum.zip(evaluations, part_inputs)
      |> Enum.map(fn {e, %{part_id: part_id}} -> Map.put(e, :part_id, part_id) end)

    {:ok, evaluations}
  end

  def update_part_attempts_and_get_activity_attempts(
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
  """
  def apply_client_evaluation(
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

    %Oli.Activities.ActivityRegistration{allow_client_evaluation: allow_client_evaluation} = Oli.Activities.get_registration_by_slug(activity_registration_slug)

    if not enforce_client_side_eval or allow_client_evaluation do

      Repo.transaction(fn ->
        part_attempts = part_attempts_input || get_latest_part_attempts(activity_attempt_guid)
        part_inputs = filter_already_evaluated(part_inputs, part_attempts)

        roll_up_fn =
          case use_fixed_score do
            nil ->
              determine_activity_rollup_fn(
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

        # Override the rollup function if no_roll_up is set
        roll_up_fn = if no_roll_up do fn result -> result end else roll_up_fn end

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

  def rollup_part_attempt_evaluations(activity_attempt_guid) do
    # find the latest part attempts
    part_attempts = get_latest_part_attempts(activity_attempt_guid)

    # Retrieve the activity attempt, and it's cross attempt information
    {activity_attempt, scoring_strategy_id, other_attempts} = retrieve_rollup_context(activity_attempt_guid)

    # Calculate the score for this activity attempt - derived strictly from its part attempts
    %Result{score: score, out_of: out_of} =
      Scoring.calculate_score(activity_attempt.revision.scoring_strategy_id, part_attempts)

    # Include this activity attempt in the aggregate scoring across all of its attempts
    now = DateTime.utc_now()
    all_attempts = [%{score: score, out_of: out_of, date_evaluated: now} | other_attempts]

    %Result{score: aggregate_score, out_of: aggregate_out_of} = Scoring.calculate_score(scoring_strategy_id, all_attempts)

    Logger.debug("rollup_part_attempt_evaluations: score: #{score}, out_of: #{out_of}")

    update_activity_attempt(activity_attempt, %{
      score: score,
      out_of: out_of,
      aggregate_score: aggregate_score,
      aggregate_out_of: aggregate_out_of,
      lifecycle_state: :evaluated,
      date_evaluated: now,
      date_submitted: now
    })
  end

  # Allows the adaptive page to mark an activity attempt as evaluated, using a given score and out_of
  defp evaluate_with_rule_engine_score(activity_attempt_guid, score, out_of) do
    Logger.debug("rollup_part_attempt_evaluations: score: #{score}, out_of: #{out_of}")

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

  # Evaluate a list of part_input submissions for a matching list of part_attempt records
  defp evaluate_submissions(_, [], _) do
    {:ok, []}
  end

  defp evaluate_submissions(activity_attempt_guid, part_inputs, part_attempts) do
    activity_attempt =
      get_activity_attempt_by(attempt_guid: activity_attempt_guid)
      |> Repo.preload(resource_attempt: [:revision], revision: [])

    do_evaluate_submissions(activity_attempt, part_inputs, part_attempts)
  end

  defp do_evaluate_submissions(
         activity_attempt,
         part_inputs,
         part_attempts,
         effective_settings \\ nil
       )

  defp do_evaluate_submissions(activity_attempt, part_inputs, part_attempts, nil) do
    effective_settings =
      Oli.Delivery.Settings.get_combined_settings(activity_attempt.resource_attempt)

    do_evaluate_submissions(activity_attempt, part_inputs, part_attempts, effective_settings)
  end

  defp do_evaluate_submissions(
         %ActivityAttempt{
           resource_attempt: resource_attempt,
           attempt_number: attempt_number
         } = activity_attempt,
         part_inputs,
         part_attempts,
         effective_settings
       ) do
    activity_model = select_model(activity_attempt)

    {:ok, %Model{parts: parts}} = Model.parse(activity_model)

    evaluations =
      case Model.parse(activity_model) do
        {:ok, %Model{rules: []}} ->
          # We need to tie the attempt_guid from the part_inputs to the attempt_guid
          # from the %PartAttempt, and then the part id from the %PartAttempt to the
          # part id in the parsed model.
          part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

          attempt_map =
            Enum.reduce(part_attempts, %{}, fn p, m -> Map.put(m, p.attempt_guid, p) end)

          # flat map the results since the results may contain an additional explanation action
          Enum.map(part_inputs, fn %{attempt_guid: attempt_guid, input: input} ->
            attempt = Map.get(attempt_map, attempt_guid)
            part = Map.get(part_map, attempt.part_id)

            context = %EvaluationContext{
              resource_attempt_number: resource_attempt.attempt_number,
              activity_attempt_number: attempt_number,
              activity_attempt_guid: activity_attempt.attempt_guid,
              part_attempt_number: attempt.attempt_number,
              part_attempt_guid: attempt.attempt_guid,
              page_id: effective_settings.resource_id,
              input: input.input
            }

            Standard.perform(attempt_guid, context, part)
            |> Explanation.maybe_set_feedback_action_explanation(%ExplanationContext{
              part: part,
              part_attempt: attempt,
              activity_attempt: activity_attempt,
              resource_attempt: resource_attempt,
              resource_revision: resource_attempt.revision,
              effective_settings: effective_settings
            })
          end)

        _ ->
          []
      end

    {:ok, evaluations}
  end

  def rollup_submitted(activity_attempt_guid) do
    get_activity_attempt_by(attempt_guid: activity_attempt_guid)
    |> update_activity_attempt(%{
      lifecycle_state: :submitted,
      date_submitted: DateTime.utc_now()
    })
  end

  defp determine_activity_rollup_fn(
         activity_attempt_guid,
         part_inputs,
         part_attempts
       ) do
    evaluated_fn = fn result ->
      rollup_part_attempt_evaluations(activity_attempt_guid)
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

  # Filters out part_inputs whose attempts have already been evaluated.  This step
  # simply lowers the burden on an activity client for having to manage this - as
  # they now can instead just choose to always submit for evaluation all parts.
  defp filter_already_evaluated(part_inputs, part_attempts) do
    already_evaluated =
      Enum.filter(part_attempts, fn p -> p.lifecycle_state == :evaluated end)
      |> Enum.map(fn e -> e.attempt_guid end)
      |> MapSet.new()

    Enum.filter(part_inputs, fn %{attempt_guid: attempt_guid} ->
      !MapSet.member?(already_evaluated, attempt_guid)
    end)
  end

end
