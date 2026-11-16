defmodule Oli.Math.MatchConfig do
  @moduledoc "Pure preparation of effective response match configuration shared by delivery and validation."

  @doc "Merges item settings into a response config using the delivery precedence rules."
  def prepare(
        %{"type" => "math_expression", "math" => %{"mode" => mode} = math} = match_config,
        %{"type" => "math_expression", "subtype" => question_type} = item_config
      ) do
    config = Map.get(item_config, "config", %{})

    math =
      math
      |> merge_shared_validation(question_type, config, mode)
      |> merge_shared_sampling(question_type, config, mode)
      |> merge_shared_unit_policy(question_type, config, mode)

    Map.put(match_config, "math", math)
  end

  def prepare(match_config, _item_config), do: match_config

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
