defmodule OliWeb.Dev.MathPrototypeLive do
  use OliWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       expression: "1 + 2",
       server_result: nil,
       client_result: nil,
       algebraic_form: default_algebraic_form(),
       algebraic_result: nil,
       algebraic_errors: [],
       algebraic_check_count: 0
     )}
  end

  @impl true
  def handle_event("set_expression", %{"expression" => expression}, socket) do
    {:noreply, assign(socket, expression: expression)}
  end

  def handle_event("parse_server", _params, socket) do
    {:noreply, assign(socket, server_result: format_server_result(socket.assigns.expression))}
  end

  def handle_event("client_parse_result", result, socket) do
    {:noreply, assign(socket, client_result: result)}
  end

  def handle_event("update_algebraic_form", %{"algebraic" => params}, socket) do
    {:noreply,
     assign(socket, algebraic_form: merge_algebraic_form(socket.assigns.algebraic_form, params))}
  end

  def handle_event("add_domain_row", _params, socket) do
    form = socket.assigns.algebraic_form
    domains = form["domains"] ++ [default_domain_row()]

    {:noreply, assign(socket, algebraic_form: Map.put(form, "domains", domains))}
  end

  def handle_event("remove_domain_row", %{"index" => index}, socket) do
    form = socket.assigns.algebraic_form
    index = parse_index(index)

    domains =
      form["domains"]
      |> List.delete_at(index)
      |> case do
        [] -> [default_domain_row()]
        rows -> rows
      end

    {:noreply, assign(socket, algebraic_form: Map.put(form, "domains", domains))}
  end

  def handle_event("check_algebraic_equivalence", %{"algebraic" => params}, socket) do
    form = merge_algebraic_form(socket.assigns.algebraic_form, params)

    try do
      check_results =
        case unit_check_enabled?(form) do
          true ->
            unit_config_result = Oli.Math.Units.config_from_form(form)
            tolerance_result = Oli.Math.Units.tolerance_from_form(form)

            {collect_config_errors([unit_config_result, tolerance_result]),
             fn ->
               {:ok, unit_config} = unit_config_result
               {:ok, tolerance} = tolerance_result

               form
               |> run_unit_check(unit_config, tolerance)
               |> format_unit_result()
             end}

          false ->
            algebraic_config_result = Oli.Math.Algebraic.config_from_form(form)
            form_config_result = Oli.Math.ExactForm.config_from_form(form)

            {collect_config_errors([algebraic_config_result, form_config_result]),
             fn ->
               {:ok, algebraic_config} = algebraic_config_result
               {:ok, form_config} = form_config_result

               case concrete_form_constraint?(form) do
                 true ->
                   form
                   |> run_form_aware_check(algebraic_config, form_config)
                   |> format_form_aware_algebraic_result()

                 false ->
                   form
                   |> run_algebraic_check(algebraic_config)
                   |> format_algebraic_result()
               end
             end}
        end

      case check_results do
        {[], run_check} ->
          result = run_check.()

          {:noreply,
           assign(socket,
             algebraic_form: form,
             algebraic_result: result,
             algebraic_errors: [],
             algebraic_check_count: socket.assigns.algebraic_check_count + 1
           )}

        {errors, _run_check} ->
          {:noreply,
           assign(socket,
             algebraic_form: form,
             algebraic_result: nil,
             algebraic_errors: errors,
             algebraic_check_count: socket.assigns.algebraic_check_count + 1
           )}
      end
    rescue
      error in UndefinedFunctionError ->
        {:noreply,
         assign(socket,
           algebraic_form: form,
           algebraic_result: nil,
           algebraic_errors: [%{field: "gleam", message: Exception.message(error)}],
           algebraic_check_count: socket.assigns.algebraic_check_count + 1
         )}
    end
  end

  defp format_server_result(expression) do
    case Oli.Math.parse(expression) do
      {:ok, %{debug: debug} = value} ->
        %{status: "ok", value: debug, inspect: inspect(value)}

      {:error, %{debug: debug} = value} ->
        %{status: "error", value: debug, inspect: inspect(value)}

      other ->
        %{status: "unknown", value: inspect(other), inspect: inspect(other)}
    end
  end

  defp default_algebraic_form do
    %{
      "expected" => "2(x+3)",
      "candidate" => "2x+6",
      "allowed_variables" => "",
      "sample_count" => "8",
      "seed" => "42",
      "max_attempts" => "64",
      "include_special_points" => "true",
      "tolerance_type" => "default",
      "abs_tolerance" => "0.0001",
      "rel_tolerance" => "0.0001",
      "epsilon" => "0.000000000001",
      "unit_mode" => "off",
      "accepted_units" => "m/s^2, cm/s^2",
      "conversion_policy" => "allow",
      "final_unit_policy" => "any",
      "form_constraint" => "none",
      "decimal_precision_rule" => "any",
      "decimal_precision_count" => "2",
      "domains" => [default_domain_row()]
    }
  end

  defp default_domain_row do
    %{
      "name" => "",
      "lower" => "",
      "lower_bound" => "inclusive",
      "upper" => "",
      "upper_bound" => "inclusive",
      "integer_only" => "false",
      "exclusions" => "",
      "preferred_values" => ""
    }
  end

  defp merge_algebraic_form(form, params) do
    params = normalize_algebraic_params(params)
    Map.merge(form, params)
  end

  defp normalize_algebraic_params(params) do
    params
    |> Map.update("domains", [default_domain_row()], fn rows ->
      rows
      |> normalize_domain_rows()
      |> case do
        [] -> [default_domain_row()]
        values -> values
      end
    end)
  end

  defp normalize_domain_rows(rows) when is_list(rows), do: rows

  defp normalize_domain_rows(rows) when is_map(rows) do
    rows
    |> Enum.sort_by(fn {index, _row} -> parse_index(index) end)
    |> Enum.map(fn {_index, row} -> row end)
  end

  defp normalize_domain_rows(_rows), do: []

  defp parse_index(index) when is_integer(index), do: index

  defp parse_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {value, ""} -> value
      _ -> 0
    end
  end

  defp parse_index(_index), do: 0

  defp collect_config_errors(results) do
    Enum.flat_map(results, fn
      {:ok, _value} -> []
      {:error, errors} -> errors
    end)
  end

  defp concrete_form_constraint?(form) do
    case form
         |> Map.get("form_constraint", "none")
         |> to_string()
         |> String.trim()
         |> String.downcase() do
      "none" -> false
      "" -> false
      _ -> true
    end
  end

  defp unit_check_enabled?(form) do
    case form
         |> Map.get("unit_mode", "off")
         |> to_string()
         |> String.trim()
         |> String.downcase() do
      "ignore" -> true
      "require" -> true
      "off" -> false
      "" -> false
      _ -> true
    end
  end

  defp run_algebraic_check(form, algebraic_config) do
    Oli.Math.Algebraic.check(form["expected"], form["candidate"], algebraic_config)
  end

  defp run_unit_check(form, unit_config, tolerance) do
    Oli.Math.Units.compare(form["expected"], form["candidate"], unit_config, tolerance)
  end

  defp run_form_aware_check(form, algebraic_config, form_config) do
    Oli.Math.ExactForm.check_algebraic(
      form["expected"],
      form["candidate"],
      algebraic_config,
      form_config
    )
  end

  defp format_algebraic_result(result) do
    {:algebraic_equivalence_result, outcome, expected_debug, candidate_debug, samples,
     rejected_samples, summary, config_summary} = result

    %{
      outcome: outcome_label(outcome),
      outcome_detail: inspect(outcome),
      expected_debug: inspect(expected_debug),
      candidate_debug: inspect(candidate_debug),
      samples: samples,
      rejected_samples: rejected_samples,
      summary: summary_to_map(summary),
      config_summary: inspect(config_summary),
      first_failure: first_failure_detail(outcome),
      exact_form: nil,
      debug: Oli.Math.Algebraic.result_debug(result)
    }
  end

  defp format_form_aware_algebraic_result(result) do
    {semantic_status, overall_outcome, equivalence, form_result} =
      case result do
        {:semantics_failed, equivalence} ->
          {"Failed", nil, equivalence, nil}

        {:semantics_passed_form_satisfied, equivalence, form_result} ->
          {"Passed", nil, equivalence, form_result}

        {:semantics_passed_form_failed, equivalence, form_result} ->
          {"Passed", "Form failed", equivalence, form_result}
      end

    equivalence
    |> format_algebraic_result()
    |> maybe_put_overall_outcome(overall_outcome)
    |> maybe_put_form_failure(form_result)
    |> Map.put(
      :exact_form,
      %{
        semantic_outcome: semantic_status,
        form_outcome: form_outcome_label(form_result),
        observed: observed_form_detail(form_result),
        failures: form_failure_details(form_result),
        debug: Oli.Math.ExactForm.form_aware_result_debug(result)
      }
    )
  end

  defp format_unit_result(result) do
    {:unit_comparison_result, outcome, expected, submitted, config} = result

    %{
      outcome: unit_outcome_label(outcome),
      outcome_detail: inspect(outcome),
      expected_debug: inspect(expected),
      candidate_debug: inspect(submitted),
      samples: [],
      rejected_samples: [],
      summary: unit_summary_to_map(outcome),
      config_summary: inspect(config),
      first_failure: unit_failure_detail(outcome),
      exact_form: nil,
      debug: Oli.Math.Units.result_debug(result)
    }
  end

  defp unit_outcome_label({:correct, _comparison}), do: "Equivalent"
  defp unit_outcome_label(:missing_unit), do: "Missing unit"
  defp unit_outcome_label({:unsupported_unit, _atom}), do: "Unsupported unit"
  defp unit_outcome_label({:incompatible_unit, _expected, _submitted}), do: "Incompatible unit"
  defp unit_outcome_label({:wrong_but_convertible_unit, _submitted}), do: "Wrong but convertible"
  defp unit_outcome_label({:unit_not_accepted, _submitted}), do: "Unit not accepted"
  defp unit_outcome_label({:numeric_mismatch_after_conversion, _comparison}), do: "Not equivalent"
  defp unit_outcome_label({:unit_syntax_error, _error}), do: "Unit syntax error"
  defp unit_outcome_label({:invalid_unit_config, _errors}), do: "Configuration error"
  defp unit_outcome_label({:invalid_numeric_comparison, _error}), do: "Configuration error"
  defp unit_outcome_label({:unsupported_value_expression, _reason}), do: "Unsupported expression"
  defp unit_outcome_label(other), do: inspect(other)

  defp unit_summary_to_map(outcome) do
    %{
      category: unit_category(outcome),
      requested: "N/A",
      valid: "N/A",
      attempts: "N/A",
      rejected: "N/A",
      variables: []
    }
  end

  defp unit_category({:correct, _comparison}), do: :correct
  defp unit_category(:missing_unit), do: :missing_unit
  defp unit_category({:unsupported_unit, _atom}), do: :unsupported_unit
  defp unit_category({:incompatible_unit, _expected, _submitted}), do: :incompatible_unit
  defp unit_category({:wrong_but_convertible_unit, _submitted}), do: :wrong_but_convertible_unit
  defp unit_category({:unit_not_accepted, _submitted}), do: :unit_not_accepted
  defp unit_category({:numeric_mismatch_after_conversion, _comparison}), do: :numeric_mismatch
  defp unit_category({:unit_syntax_error, _error}), do: :unit_syntax_error
  defp unit_category({:invalid_unit_config, _errors}), do: :invalid_unit_config
  defp unit_category({:invalid_numeric_comparison, _error}), do: :invalid_numeric_comparison
  defp unit_category({:unsupported_value_expression, _reason}), do: :unsupported_value_expression
  defp unit_category(other), do: other

  defp unit_failure_detail({:correct, _comparison}), do: nil
  defp unit_failure_detail(outcome), do: inspect(outcome)

  defp maybe_put_overall_outcome(result, nil), do: result
  defp maybe_put_overall_outcome(result, outcome), do: Map.put(result, :outcome, outcome)

  defp maybe_put_form_failure(result, {:form_not_satisfied, _observed, _failures} = form_result) do
    Map.put(result, :first_failure, form_failure_details(form_result))
  end

  defp maybe_put_form_failure(result, _form_result), do: result

  defp outcome_label({:equivalent, _count}), do: "Equivalent"
  defp outcome_label({:not_equivalent, _reason}), do: "Not equivalent"
  defp outcome_label({:expected_parse_failed, _error}), do: "Parse error"
  defp outcome_label({:candidate_parse_failed, _error}), do: "Parse error"
  defp outcome_label({:validation_failed, _errors}), do: "Validation error"
  defp outcome_label({:insufficient_valid_samples, _error}), do: "Insufficient valid samples"
  defp outcome_label({:invalid_configuration, _error}), do: "Configuration error"

  defp outcome_label({:unsupported_expression_shape, _side, _reason}),
    do: "Unsupported expression"

  defp outcome_label({:expected_evaluation_failed, _error}), do: "Evaluation error"
  defp outcome_label(other), do: inspect(other)

  defp first_failure_detail({:not_equivalent, {:value_mismatch, failure}}), do: inspect(failure)

  defp first_failure_detail({:not_equivalent, {:candidate_undefined, failure}}),
    do: inspect(failure)

  defp first_failure_detail({:not_equivalent, {:comparison_failed, error}}), do: inspect(error)
  defp first_failure_detail(_outcome), do: nil

  defp summary_to_map(
         {:equivalence_summary, category, requested, valid, attempts, rejected, first_failure,
          variables}
       ) do
    %{
      category: category,
      requested: requested,
      valid: valid,
      attempts: attempts,
      rejected: rejected,
      first_failure: first_failure,
      variables: variables
    }
  end

  defp summary_to_map(summary), do: %{raw: inspect(summary)}

  defp form_outcome_label(nil), do: "Not checked"
  defp form_outcome_label({:form_satisfied, _observed}), do: "Satisfied"
  defp form_outcome_label({:form_not_satisfied, _observed, _failures}), do: "Failed"
  defp form_outcome_label({:form_check_parse_failed, _error}), do: "Parse error"
  defp form_outcome_label({:invalid_form_config, _error}), do: "Configuration error"
  defp form_outcome_label(other), do: inspect(other)

  defp observed_form_detail(nil), do: "Not checked"
  defp observed_form_detail({:form_satisfied, observed}), do: inspect(observed)
  defp observed_form_detail({:form_not_satisfied, observed, _failures}), do: inspect(observed)
  defp observed_form_detail({:form_check_parse_failed, error}), do: inspect(error)
  defp observed_form_detail({:invalid_form_config, error}), do: inspect(error)
  defp observed_form_detail(other), do: inspect(other)

  defp form_failure_details({:form_not_satisfied, _observed, failures}), do: inspect(failures)
  defp form_failure_details({:form_check_parse_failed, error}), do: inspect(error)
  defp form_failure_details({:invalid_form_config, error}), do: inspect(error)
  defp form_failure_details(_result), do: "None"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container p-4">
      <h1 class="text-2xl font-semibold mb-2">Math Prototype</h1>
      <p class="text-sm text-gray-600 mb-6">
        Dev-only playground for comparing server and browser Gleam math parser output.
      </p>

      <div id="math-prototype" phx-hook="MathPrototype" class="space-y-6">
        <form phx-change="set_expression" class="max-w-3xl">
          <.input
            id="math-expression"
            type="text"
            name="expression"
            label="Math expression"
            value={@expression}
          />
        </form>

        <div class="flex flex-wrap gap-2">
          <.button phx-click="parse_server">Parse on server</.button>
          <.button type="button" id="parse-client">Parse in browser</.button>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="border rounded p-4">
            <h2 class="text-lg font-semibold mb-3">Server result</h2>
            <.result_panel result={@server_result} />
          </div>

          <div class="border rounded p-4">
            <h2 class="text-lg font-semibold mb-3">Browser result</h2>
            <.result_panel result={@client_result} />
          </div>
        </div>

        <section id="algebraic-equivalence-panel" class="border rounded p-4 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Algebraic Equivalence</h2>
            <p class="text-sm text-gray-600">
              Developer-only sampling check. Deterministic sampling is not symbolic proof.
            </p>
          </div>

          <form
            id="algebraic-form"
            phx-change="update_algebraic_form"
            phx-submit="check_algebraic_equivalence"
            novalidate
            class="space-y-4"
          >
            <div class="grid gap-3 md:grid-cols-2">
              <.input
                id="algebraic-expected"
                type="text"
                name="algebraic[expected]"
                label="Expected expression"
                value={@algebraic_form["expected"]}
              />
              <.input
                id="algebraic-candidate"
                type="text"
                name="algebraic[candidate]"
                label="Candidate expression"
                value={@algebraic_form["candidate"]}
              />
            </div>

            <div class="grid gap-3 md:grid-cols-4">
              <.input
                id="algebraic-sample-count"
                type="number"
                name="algebraic[sample_count]"
                label="Samples"
                value={@algebraic_form["sample_count"]}
              />
              <.input
                id="algebraic-seed"
                type="number"
                name="algebraic[seed]"
                label="Seed"
                value={@algebraic_form["seed"]}
              />
              <.input
                id="algebraic-max-attempts"
                type="number"
                name="algebraic[max_attempts]"
                label="Max attempts"
                value={@algebraic_form["max_attempts"]}
              />
              <.input
                id="algebraic-allowed-variables"
                type="text"
                name="algebraic[allowed_variables]"
                label="Allowed variables"
                value={@algebraic_form["allowed_variables"]}
              />
            </div>

            <div class="grid gap-3 md:grid-cols-4">
              <label class="text-sm">
                <span class="font-semibold">Tolerance</span>
                <select
                  id="algebraic-tolerance-type"
                  name="algebraic[tolerance_type]"
                  class="form-select block w-full mt-1"
                >
                  <option value="default" selected={@algebraic_form["tolerance_type"] == "default"}>
                    Default
                  </option>
                  <option value="none" selected={@algebraic_form["tolerance_type"] == "none"}>
                    None
                  </option>
                  <option value="absolute" selected={@algebraic_form["tolerance_type"] == "absolute"}>
                    Absolute
                  </option>
                  <option value="relative" selected={@algebraic_form["tolerance_type"] == "relative"}>
                    Relative
                  </option>
                  <option
                    value="absolute_or_relative"
                    selected={@algebraic_form["tolerance_type"] == "absolute_or_relative"}
                  >
                    Absolute or relative
                  </option>
                </select>
              </label>
              <.input
                id="algebraic-abs-tolerance"
                type="text"
                name="algebraic[abs_tolerance]"
                label="Abs"
                value={@algebraic_form["abs_tolerance"]}
              />
              <.input
                id="algebraic-rel-tolerance"
                type="text"
                name="algebraic[rel_tolerance]"
                label="Rel"
                value={@algebraic_form["rel_tolerance"]}
              />
              <.input
                id="algebraic-epsilon"
                type="text"
                name="algebraic[epsilon]"
                label="Epsilon"
                value={@algebraic_form["epsilon"]}
              />
            </div>

            <div id="unit-equivalence-controls" class="grid gap-3 md:grid-cols-4">
              <label class="text-sm">
                <span class="font-semibold">Units</span>
                <select
                  id="algebraic-unit-mode"
                  name="algebraic[unit_mode]"
                  class="form-select block w-full mt-1"
                >
                  <option value="off" selected={@algebraic_form["unit_mode"] == "off"}>
                    Off
                  </option>
                  <option value="ignore" selected={@algebraic_form["unit_mode"] == "ignore"}>
                    Ignore
                  </option>
                  <option value="require" selected={@algebraic_form["unit_mode"] == "require"}>
                    Require
                  </option>
                </select>
              </label>

              <.input
                id="algebraic-accepted-units"
                type="text"
                name="algebraic[accepted_units]"
                label="Accepted units"
                value={@algebraic_form["accepted_units"]}
              />

              <label class="text-sm">
                <span class="font-semibold">Conversion</span>
                <select
                  id="algebraic-conversion-policy"
                  name="algebraic[conversion_policy]"
                  class="form-select block w-full mt-1"
                >
                  <option value="allow" selected={@algebraic_form["conversion_policy"] == "allow"}>
                    Allow
                  </option>
                  <option
                    value="disallow"
                    selected={@algebraic_form["conversion_policy"] == "disallow"}
                  >
                    Disallow
                  </option>
                </select>
              </label>

              <label class="text-sm">
                <span class="font-semibold">Final unit</span>
                <select
                  id="algebraic-final-unit-policy"
                  name="algebraic[final_unit_policy]"
                  class="form-select block w-full mt-1"
                >
                  <option value="any" selected={@algebraic_form["final_unit_policy"] == "any"}>
                    Any accepted
                  </option>
                  <option
                    value="strict"
                    selected={@algebraic_form["final_unit_policy"] == "strict"}
                  >
                    Strict
                  </option>
                </select>
              </label>
            </div>

            <div id="exact-form-controls" class="grid gap-3 md:grid-cols-3">
              <label class="text-sm">
                <span class="font-semibold">Exact form</span>
                <select
                  id="algebraic-form-constraint"
                  name="algebraic[form_constraint]"
                  class="form-select block w-full mt-1"
                >
                  <option value="none" selected={@algebraic_form["form_constraint"] == "none"}>
                    None
                  </option>
                  <option value="integer" selected={@algebraic_form["form_constraint"] == "integer"}>
                    Integer
                  </option>
                  <option value="fraction" selected={@algebraic_form["form_constraint"] == "fraction"}>
                    Fraction
                  </option>
                  <option
                    value="simplified_fraction"
                    selected={@algebraic_form["form_constraint"] == "simplified_fraction"}
                  >
                    Simplified fraction
                  </option>
                  <option value="decimal" selected={@algebraic_form["form_constraint"] == "decimal"}>
                    Decimal
                  </option>
                </select>
              </label>

              <label class="text-sm">
                <span class="font-semibold">Decimal precision</span>
                <select
                  id="algebraic-decimal-precision-rule"
                  name="algebraic[decimal_precision_rule]"
                  class="form-select block w-full mt-1"
                >
                  <option value="any" selected={@algebraic_form["decimal_precision_rule"] == "any"}>
                    Any
                  </option>
                  <option
                    value="exactly"
                    selected={@algebraic_form["decimal_precision_rule"] == "exactly"}
                  >
                    Exactly
                  </option>
                  <option
                    value="at_least"
                    selected={@algebraic_form["decimal_precision_rule"] == "at_least"}
                  >
                    At least
                  </option>
                  <option
                    value="at_most"
                    selected={@algebraic_form["decimal_precision_rule"] == "at_most"}
                  >
                    At most
                  </option>
                </select>
              </label>

              <.input
                id="algebraic-decimal-precision-count"
                type="number"
                name="algebraic[decimal_precision_count]"
                label="Decimal places"
                value={@algebraic_form["decimal_precision_count"]}
              />
            </div>

            <label class="inline-flex items-center gap-2 text-sm">
              <input type="hidden" name="algebraic[include_special_points]" value="false" />
              <input
                id="algebraic-include-special-points"
                type="checkbox"
                name="algebraic[include_special_points]"
                value="true"
                checked={@algebraic_form["include_special_points"] == "true"}
              />
              <span>Include special points</span>
            </label>

            <div id="algebraic-domain-rows" class="space-y-3">
              <div class="flex items-center justify-between">
                <h3 class="font-semibold">Per-variable domains</h3>
                <.button type="button" phx-click="add_domain_row">Add domain row</.button>
              </div>

              <div
                :for={{row, index} <- Enum.with_index(@algebraic_form["domains"])}
                id={"algebraic-domain-row-#{index}"}
                class="grid gap-3 md:grid-cols-8 border rounded p-3"
              >
                <.input
                  id={"domain-#{index}-name"}
                  type="text"
                  name={"algebraic[domains][#{index}][name]"}
                  label="Variable"
                  value={row["name"]}
                />
                <.input
                  id={"domain-#{index}-lower"}
                  type="text"
                  name={"algebraic[domains][#{index}][lower]"}
                  label="Lower"
                  value={row["lower"]}
                />
                <label class="text-sm">
                  <span class="font-semibold">Lower bound</span>
                  <select
                    id={"domain-#{index}-lower-bound"}
                    name={"algebraic[domains][#{index}][lower_bound]"}
                    class="form-select block w-full mt-1"
                  >
                    <option value="inclusive" selected={row["lower_bound"] == "inclusive"}>
                      Inclusive
                    </option>
                    <option value="exclusive" selected={row["lower_bound"] == "exclusive"}>
                      Exclusive
                    </option>
                  </select>
                </label>
                <.input
                  id={"domain-#{index}-upper"}
                  type="text"
                  name={"algebraic[domains][#{index}][upper]"}
                  label="Upper"
                  value={row["upper"]}
                />
                <label class="text-sm">
                  <span class="font-semibold">Upper bound</span>
                  <select
                    id={"domain-#{index}-upper-bound"}
                    name={"algebraic[domains][#{index}][upper_bound]"}
                    class="form-select block w-full mt-1"
                  >
                    <option value="inclusive" selected={row["upper_bound"] == "inclusive"}>
                      Inclusive
                    </option>
                    <option value="exclusive" selected={row["upper_bound"] == "exclusive"}>
                      Exclusive
                    </option>
                  </select>
                </label>
                <.input
                  id={"domain-#{index}-exclusions"}
                  type="text"
                  name={"algebraic[domains][#{index}][exclusions]"}
                  label="Exclusions"
                  value={row["exclusions"]}
                />
                <.input
                  id={"domain-#{index}-preferred-values"}
                  type="text"
                  name={"algebraic[domains][#{index}][preferred_values]"}
                  label="Preferred"
                  value={row["preferred_values"]}
                />
                <div class="flex items-end gap-2">
                  <label class="inline-flex items-center gap-2 text-sm mb-2">
                    <input
                      type="hidden"
                      name={"algebraic[domains][#{index}][integer_only]"}
                      value="false"
                    />
                    <input
                      id={"domain-#{index}-integer-only"}
                      type="checkbox"
                      name={"algebraic[domains][#{index}][integer_only]"}
                      value="true"
                      checked={row["integer_only"] == "true"}
                    />
                    <span>Integer</span>
                  </label>
                  <button
                    type="button"
                    class="btn btn-sm btn-outline-danger mb-1"
                    phx-click="remove_domain_row"
                    phx-value-index={index}
                  >
                    Remove
                  </button>
                </div>
              </div>
            </div>

            <%= if @algebraic_errors != [] do %>
              <div id="algebraic-errors" class="bg-red-50 border border-red-300 rounded p-4 text-sm">
                <div class="font-semibold text-red-900">Check failed</div>
                <div class="text-red-800">Checks run: {@algebraic_check_count}</div>
                <ul class="list-disc pl-5">
                  <li :for={error <- @algebraic_errors}>
                    <span>{error.field}</span>: <span>{error.message}</span>
                  </li>
                </ul>
              </div>
            <% end %>

            <.button id="check-algebraic-equivalence" type="submit">Check equivalence</.button>
          </form>

          <.algebraic_result_panel
            result={@algebraic_result}
            check_count={@algebraic_check_count}
          />
        </section>
      </div>
    </div>
    """
  end

  attr :result, :any, required: true

  defp result_panel(assigns) do
    assigns =
      assign(assigns,
        status: result_value(assigns.result, :status),
        value: result_value(assigns.result, :value),
        inspect: result_value(assigns.result, :inspect)
      )

    ~H"""
    <%= if @result do %>
      <div class="space-y-2 text-sm">
        <div>
          <span class="font-semibold">Status:</span>
          <span>{@status}</span>
        </div>
        <div>
          <span class="font-semibold">Value:</span>
          <code class="bg-gray-50 p-1 rounded">{@value}</code>
        </div>
        <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@inspect}</code></pre>
      </div>
    <% else %>
      <p class="text-sm text-gray-500">No parse has been run yet.</p>
    <% end %>
    """
  end

  defp result_value(nil, _key), do: nil
  defp result_value(result, key), do: Map.get(result, key) || Map.get(result, Atom.to_string(key))

  attr :result, :any, required: true
  attr :check_count, :integer, required: true

  defp algebraic_result_panel(assigns) do
    ~H"""
    <%= if @result do %>
      <div
        id="algebraic-result"
        class={[
          "space-y-4 text-sm border rounded p-4",
          algebraic_result_classes(@result.outcome)
        ]}
      >
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <h3 class="text-base font-semibold">Last equivalence check</h3>
            <div class="text-gray-700">Checks run: {@check_count}</div>
          </div>
          <div
            id="algebraic-outcome"
            class="rounded px-3 py-1 text-sm font-semibold bg-white border"
          >
            {@result.outcome}
          </div>
        </div>

        <div id="algebraic-summary" class="grid gap-2 md:grid-cols-3">
          <div>
            <span class="font-semibold">
              {if @result.exact_form, do: "Semantic category:", else: "Category:"}
            </span>
            {inspect(@result.summary.category)}
          </div>
          <div><span class="font-semibold">Requested:</span> {@result.summary.requested}</div>
          <div><span class="font-semibold">Valid:</span> {@result.summary.valid}</div>
          <div><span class="font-semibold">Attempts:</span> {@result.summary.attempts}</div>
          <div><span class="font-semibold">Rejected:</span> {@result.summary.rejected}</div>
          <div>
            <span class="font-semibold">Variables:</span> {Enum.join(@result.summary.variables, ", ")}
          </div>
        </div>

        <div id="algebraic-first-failure">
          <span class="font-semibold">First failure:</span>
          <code class="bg-gray-50 p-1 rounded">{@result.first_failure || "None"}</code>
        </div>

        <%= if @result.exact_form do %>
          <div id="exact-form-result" class="grid gap-2 md:grid-cols-2 border rounded p-3 bg-white">
            <div>
              <span class="font-semibold">Semantic outcome:</span>
              <span id="exact-form-semantic-outcome">{@result.exact_form.semantic_outcome}</span>
            </div>
            <div>
              <span class="font-semibold">Form outcome:</span>
              <span id="exact-form-form-outcome">{@result.exact_form.form_outcome}</span>
            </div>
            <div class="md:col-span-2">
              <span class="font-semibold">Observed form:</span>
              <code class="bg-gray-50 p-1 rounded">{@result.exact_form.observed}</code>
            </div>
            <div class="md:col-span-2">
              <span class="font-semibold">Form failures:</span>
              <code class="bg-gray-50 p-1 rounded">{@result.exact_form.failures}</code>
            </div>
            <div id="exact-form-debug-text" class="md:col-span-2">
              <h3 class="font-semibold">Exact-form debug text</h3>
              <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@result.exact_form.debug}</code></pre>
            </div>
          </div>
        <% end %>

        <div id="algebraic-sample-comparisons">
          <h3 class="font-semibold">Accepted sample comparisons</h3>
          <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{inspect(@result.samples, pretty: true, limit: :infinity)}</code></pre>
        </div>

        <div id="algebraic-rejected-samples">
          <h3 class="font-semibold">Rejected sample summaries</h3>
          <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{inspect(@result.rejected_samples, pretty: true, limit: :infinity)}</code></pre>
        </div>

        <div id="algebraic-expression-debug" class="grid gap-3 md:grid-cols-2">
          <div>
            <h3 class="font-semibold">Expected debug</h3>
            <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@result.expected_debug}</code></pre>
          </div>
          <div>
            <h3 class="font-semibold">Candidate debug</h3>
            <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@result.candidate_debug}</code></pre>
          </div>
        </div>

        <div id="algebraic-debug-text">
          <h3 class="font-semibold">Stable debug text</h3>
          <pre class="bg-gray-50 p-3 rounded overflow-auto"><code>{@result.debug}</code></pre>
        </div>
      </div>
    <% else %>
      <p id="algebraic-empty-result" class="text-sm text-gray-500">
        No equivalence check has been run yet.
      </p>
    <% end %>
    """
  end

  defp algebraic_result_classes("Equivalent"), do: "bg-green-50 border-green-300"
  defp algebraic_result_classes("Not equivalent"), do: "bg-yellow-50 border-yellow-300"
  defp algebraic_result_classes(_outcome), do: "bg-red-50 border-red-300"
end
