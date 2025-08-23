defmodule Oli.Delivery.Attempts.ActivityLifecycle.Evaluate do
  @moduledoc """
  Provides core functionality for **Activity Evaluation** within the delivery system.

  This module is responsible for evaluating student submissions at the *Activity Attempt* level,
  aggregating the results from multiple *Part Attempts*. Evaluation logic is driven by
  the model and rules defined for each activity. Depending on the context (adaptive vs
  non-adaptive page, client-side vs server-side), different evaluation strategies are applied.

  ### Key Responsibilities:
  - Evaluate part attempts and roll up results to the activity attempt level.
  - Support both **server-side standard evaluation** and **client-side rule-based evaluation** workflows.
  - Handle evaluation contexts such as preview/testing modes, adaptive rules engines, and manual scoring.
  - Persist evaluation results, update progress metrics, and create snapshots/logs for analytics and experiments.

  ### Evaluation Modes:
  - **Standard Evaluation**: Traditional server-side evaluation using parts' input and scoring logic.
  - **Rules-based Evaluation**: For adaptive pages, leverages a rules engine to compute scores and feedback dynamically.
  - **Client-side Evaluation**: Accepts externally evaluated part scores (e.g., from the front-end) and persists them server-side.
  - **Preview/Test Evaluation**: Allows local preview/testing of activity evaluations without persisting results.

  ### Public API Functions:

  Please resist adding any new functions to this module.  If you think you need to add a new function, please reach out
  for guidance as what exists currently should be sufficient for your needs.

  #### `evaluate_activity/4`
  Main entry point to evaluate an activity based on student part inputs. Automatically determines whether to use the rules engine or
  standard evaluation based on the activity model.

  - **Params**: `section_slug`, `activity_attempt_guid`, `part_inputs`, `datashop_session_id`
  - **Behavior**: Selects evaluation strategy (rules engine or standard), processes input, persists results.
  - **Returns**: Evaluation outcome or error.

  ---

  #### `evaluate_from_input/5`
  Processes standard, non-adaptive evaluations by validating and scoring each submitted part input. Use this
  in situations where at the calling point it is guaranteed that the activity is not adaptive. This allows
  for individual part evaluations.

  - **Params**: `section_slug`, `activity_attempt_guid`, `part_inputs`, `datashop_session_id`, optional `part_attempts`
  - **Behavior**: Filters out parts already evaluated, evaluates fresh submissions, and performs rollup to the activity level.
  - **Returns**: `{:ok, results}` or `{:error, reason}`

  ---

  #### `apply_client_evaluation/5`
  Processes already evaluated results - some either a client-side activity or some other process external to the system.

  - **Params**: `section_slug`, `activity_attempt_guid`, `client_evaluations`, `datashop_session_id`, optional opts
  - **Options**:
    - `:part_attempts_input`: Pre-fetched part attempts.
    - `:use_fixed_score`: Forces a fixed score/out_of on rollup.
    - `:no_roll_up`: Disables rollup after part evaluation.
    - `:enforce_client_side_eval`: Ensures client-side evaluation is permitted by the activity type.
  - **Returns**: `{:ok, results}` or `{:error, reason}`

  ---

  #### `evaluate_from_preview/2`
  Allows for evaluation of an activity model in preview or test mode, without affecting persistent data.

  - **Params**: `activity_model`, `part_inputs`
  - **Behavior**: Processes inputs against the activity model locally.
  - **Returns**: Local evaluation results in-memory.

  ---

  This module is part of the delivery engine responsible for executing and managing student workflows across different activity types.
  """

  import Oli.Delivery.Attempts.Core
  import Oli.Delivery.Attempts.ActivityLifecycle.Persistence
  import Oli.Delivery.Attempts.ActivityLifecycle.Utils

  require Logger

  import Ecto.Query, warn: false

  alias Oli.Repo
  alias Oli.Delivery.Evaluation.{EvaluationContext}
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ClientEvaluation}
  alias Oli.Delivery.Snapshots
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Activities.Model
  alias Oli.Delivery.Experiments.LogWorker
  alias Oli.Delivery.Attempts.ActivityLifecycle.RollUp

  @doc """
  Evaluates a student submission for a given activity attempt and part inputs.  This function
  will determine the appropriate evaluation strategy based on the activity model and the
  part attempts that have already been submitted. For adaptive pages, this function will
  evaluate the activity using the rules engine, and then apply the results as "client side"
  evaluated results.  For non-adaptive pages, this function will evaluate the activity using
  the standard server-side evaluation strategy.
  """
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
  def evaluate_from_input(
        section_slug,
        activity_attempt_guid,
        part_inputs,
        datashop_session_id,
        part_attempts \\ nil
      ) do
    Repo.transaction(fn ->
      part_attempts =
        case part_attempts do
          nil -> get_latest_part_attempts(activity_attempt_guid)
          _ -> part_attempts
        end

      part_inputs = filter_already_evaluated(part_inputs, part_attempts)

      roll_up_fn =
        RollUp.determine_activity_rollup_fn(activity_attempt_guid, part_inputs, part_attempts)

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

        # Override the rollup function if no_roll_up is set
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

  @doc """
  Performs a test evaluation of an activity for external agents to test activities.

  Takes an activity JSON model, an activity type slug, and part inputs to simulate
  a student submission and returns the matching response from the activity model.

  ## Parameters
  - `activity_json`: JSON string containing the activity model
  - `activity_type_slug`: The slug of the activity type (e.g., "oli_multiple_choice")
  - `part_inputs`: List of maps containing part_id and input values

  ## Returns
  - `{:ok, evaluations}` with the evaluation results for each part
  - `{:error, reason}` if evaluation fails
  """
  @spec perform_test_eval(String.t(), String.t(), [map()]) :: {:ok, [map()]} | {:error, any}
  def perform_test_eval(activity_json, activity_type_slug, part_inputs) do
    with {:ok, activity_map} <- Jason.decode(activity_json),
         {:ok, registration} <- get_activity_registration(activity_type_slug),
         {:ok, evaluations} <- do_test_evaluation(activity_map, registration, part_inputs) do
      {:ok, evaluations}
    else
      {:error, reason} -> {:error, reason}
      error -> {:error, inspect(error)}
    end
  end

  defp get_activity_registration(activity_type_slug) do
    case Oli.Activities.get_registration_by_slug(activity_type_slug) do
      nil -> {:error, "Activity type '#{activity_type_slug}' not found"}
      registration -> {:ok, registration}
    end
  end

  defp do_test_evaluation(activity_map, _registration, part_inputs) do
    case Model.parse(activity_map) do
      {:ok, %Model{parts: parts}} ->
        part_map = Enum.reduce(parts, %{}, fn p, m -> Map.put(m, p.id, p) end)

        evaluations =
          Enum.map(part_inputs, fn part_input ->
            part_id = Map.get(part_input, "part_id") || Map.get(part_input, :part_id)
            input = Map.get(part_input, "input") || Map.get(part_input, :input)

            case Map.get(part_map, part_id) do
              nil ->
                %{
                  part_id: part_id,
                  error: "Part with id '#{part_id}' not found in activity model"
                }

              part ->
                # Create evaluation context for testing
                context = %EvaluationContext{
                  resource_attempt_number: 1,
                  activity_attempt_number: 1,
                  part_attempt_number: 1,
                  page_id: 1,
                  activity_attempt_guid: "test_activity_#{System.unique_integer([:positive])}",
                  part_attempt_guid: "test_part_#{System.unique_integer([:positive])}",
                  input: input
                }

                case Oli.Delivery.Evaluation.Evaluator.evaluate(part, context, 1.0) do
                  {:ok, result} ->
                    Map.put(result, :part_id, part_id)

                  {:error, error} ->
                    %{
                      part_id: part_id,
                      error: "Evaluation failed: #{inspect(error)}"
                    }
                end
            end
          end)

        {:ok, evaluations}

      {:error, reason} ->
        {:error, "Failed to parse activity model: #{inspect(reason)}"}
    end
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

        Oli.Delivery.Evaluation.Evaluator.evaluate(part, context, 1.0)
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

  def update_part_attempts_for_activity(activity_attempt, datashop_session_id, effective_settings) do
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
          input: %Oli.Delivery.Attempts.Core.StudentInput{input: input, files: files}
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

  defp submit_active_part_attempts(part_attempts) do
    now = Timex.now()

    part_attempts
    |> Enum.filter(fn pa -> pa.lifecycle_state == :active end)
    |> Enum.map(fn pa ->
      %{pa | lifecycle_state: :submitted, date_submitted: now, updated_at: now}
    end)
  end

  defp evaluate_from_rules(
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
                 part_attempts: part_attempts,
                 use_fixed_score: {score, out_of}
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

  # Retrieving the extrinsic state of the resource attempt must take
  # into account if the blob storage API is in use for extrinsic state.
  defp fetch_extrinsic_state(resource_attempt) do
    if Application.get_env(:oli, :blob_storage)[:use_deprecated_api] do
      resource_attempt.state
    else
      Oli.Delivery.TextBlob.read(
        resource_attempt.attempt_guid,
        "{}"
      )
      |> case do
        {:ok, state} ->
          case Jason.decode(state) do
            {:ok, decoded_state} -> decoded_state
            _ -> %{}
          end

        _ ->
          %{}
      end
    end
  end

  defp assemble_full_adaptive_state(
         resource_attempt,
         activities_required_for_evaluation,
         part_inputs
       ) do
    extrinsic_state = fetch_extrinsic_state(resource_attempt)

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

  # Allows the adaptive page to mark an activity attempt as evaluated, using a given score and out_of
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
end
