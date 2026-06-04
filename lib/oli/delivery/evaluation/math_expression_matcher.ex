defmodule Oli.Delivery.Evaluation.MathExpressionMatcher do
  @moduledoc """
  Normalizes Gleam `matchConfig` evaluation into the standard evaluator's
  boolean match boundary.
  """

  alias Oli.Activities.Model.Part
  alias Oli.Delivery.Evaluation.EvaluationContext
  alias Oli.Math.Match

  @spec match?(map(), EvaluationContext.t(), Part.t()) :: {:ok, boolean()} | {:error, term()}
  def match?(match_config, %EvaluationContext{input: submitted}, %Part{} = part) do
    match_config
    |> merge_question_config(part)
    |> evaluate(submitted)
  end

  @spec evaluate(map() | String.t(), String.t()) :: {:ok, boolean()} | {:error, term()}
  def evaluate(match_config, submitted) when is_binary(submitted) do
    case Match.evaluate_json(match_config, submitted) do
      {:ok, result} -> normalize_result(result)
      {:error, error} -> {:error, error}
    end
  end

  defp normalize_result({:match_matched, _diagnostics}), do: {:ok, true}
  defp normalize_result({:match_not_matched, _diagnostics}), do: {:ok, false}
  defp normalize_result({:match_invalid_submission, _diagnostics}), do: {:ok, false}
  defp normalize_result({:match_invalid_config, error}), do: {:error, error}

  defp merge_question_config(
         %{"type" => "math_expression", "math" => %{"mode" => mode} = math} = match_config,
         %Part{
           item_config: %{"type" => "math_expression", "subtype" => question_type} = item_config
         }
       ) do
    config = Map.get(item_config, "config", %{})

    math =
      math
      |> merge_shared_validation(question_type, config, mode)
      |> merge_shared_sampling(question_type, config, mode)
      |> merge_shared_unit_policy(question_type, config, mode)

    Map.put(match_config, "math", math)
  end

  defp merge_question_config(match_config, _part), do: match_config

  defp merge_shared_validation(math, question_type, config, mode)
       when question_type in ["algebraic", "expression_with_units"] and
              mode in ["algebraic_equivalence", "unit_aware"] do
    case normalize_validation(Map.get(config, "validation")) do
      nil -> math
      validation -> Map.put(math, "validation", validation)
    end
  end

  defp merge_shared_validation(math, _question_type, _config, _mode), do: math

  defp merge_shared_sampling(math, question_type, config, mode)
       when question_type in ["algebraic", "expression_with_units"] and
              mode in ["algebraic_equivalence", "unit_aware"] do
    case Map.get(config, "sampling") do
      sampling when is_map(sampling) -> Map.put(math, "sampling", sampling)
      _ -> math
    end
  end

  defp merge_shared_sampling(math, _question_type, _config, _mode), do: math

  defp merge_shared_unit_policy(math, question_type, config, "unit_aware")
       when question_type in ["number_with_units", "expression_with_units"] do
    case Map.get(config, "unitPolicy") do
      unit_policy when is_map(unit_policy) -> Map.put(math, "unitPolicy", unit_policy)
      _ -> math
    end
  end

  defp merge_shared_unit_policy(math, _question_type, _config, _mode), do: math

  defp normalize_validation(%{} = validation) do
    validation
    |> Map.update("domains", [], fn
      domains when is_list(domains) -> Enum.map(domains, &normalize_domain/1)
      _ -> []
    end)
  end

  defp normalize_validation(_), do: nil

  defp normalize_domain(%{} = domain) do
    domain
    |> normalize_bound("lower", "lowerInclusive")
    |> normalize_bound("upper", "upperInclusive")
  end

  defp normalize_domain(domain), do: domain

  defp normalize_bound(domain, bound_key, inclusive_key) do
    case Map.get(domain, bound_key) do
      %{"value" => value} = bound ->
        domain
        |> Map.put(bound_key, value)
        |> Map.put(inclusive_key, Map.get(bound, "inclusive", true))

      _ ->
        domain
    end
  end
end
