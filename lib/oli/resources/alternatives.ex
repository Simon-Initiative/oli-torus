defmodule Oli.Resources.Alternatives do
  @moduledoc """
  Resolves and selects versioned Alternatives groups.

  New experiment-controlled revisions persist `experiment_controlled`; the historical
  `upgrade_decision_point` value remains a read/ingest alias.
  """
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.SelectAllStrategy
  alias Oli.Resources.Alternatives.UserSectionPreferenceStrategy
  alias Oli.Resources.Alternatives.ExperimentControlledStrategy

  require Logger

  @invalid_nested_metric "oli.alternatives.invalid_nested_render"

  @doc """
  Selects one or more alternatives using the element's specified strategy.

  Returns a list of `Oli.Resources.Alternatives.Selection` structs.
  """
  def select(
        %AlternativesStrategyContext{alternative_groups_by_id: by_id} = context,
        %{"alternatives_id" => alternatives_id} = alternatives_element
      ) do
    strategy_name =
      by_id |> Map.get(alternatives_id) |> Map.fetch!(:strategy) |> normalize_strategy!()

    strategy(strategy_name).select(context, alternatives_element)
  end

  @doc """
  Prepares experiment-backed alternatives decisions for delivery before page rendering.

  Returns `{decisions_by_placement_element_id, attribution_payloads}`. The decision map
  is consumed by `select/2` during rendering so that delivery render does not need
  to assign learners or record exposure.
  """
  def prepare_delivery_decisions(%AlternativesStrategyContext{} = context, content) do
    ExperimentControlledStrategy.prepare_delivery_decisions(context, content)
  end

  @doc "Prepares delivery decisions from Alternatives placements already classified as valid."
  def prepare_classified_delivery_decisions(%AlternativesStrategyContext{} = context, placements) do
    ExperimentControlledStrategy.prepare_classified_delivery_decisions(context, placements)
  end

  @doc "Returns inert first-alternative decisions for experiment placements."
  def fallback_delivery_decisions(content) do
    ExperimentControlledStrategy.fallback_delivery_decisions(content)
  end

  @doc "Returns inert decisions from an already classified list of Alternatives placements."
  def fallback_classified_delivery_decisions(placements) do
    ExperimentControlledStrategy.fallback_classified_delivery_decisions(placements)
  end

  @doc """
  Restricts experiment-controlled placements to their prepared selected branch.

  This is used before activity realization so hidden alternatives do not create activity
  attempts or contribute to learner completion. Placements may occur inside ordinary
  containers. Invalid Alternatives nested beneath another Alternatives placement are
  reduced to their first local branch and never consume an experiment decision.
  """
  def apply_experiment_decisions(
        %{"model" => model} = content,
        alternative_groups_by_id,
        decisions
      )
      when is_list(model) and is_map(alternative_groups_by_id) and is_map(decisions) do
    selected_model =
      apply_decisions(model, false, alternative_groups_by_id, decisions)

    Map.put(content, "model", selected_model)
  end

  def apply_experiment_decisions(content, _alternative_groups_by_id, _decisions), do: content

  defp apply_decisions(elements, inside_alternatives?, groups, decisions)
       when is_list(elements) do
    Enum.map(elements, &apply_decision(&1, inside_alternatives?, groups, decisions))
  end

  defp apply_decision(
         %{"type" => "alternatives"} = element,
         true,
         groups,
         decisions
       ) do
    report_invalid_nested_alternatives(element)

    element
    |> keep_first_alternative()
    |> map_decision_children(true, groups, decisions)
  end

  defp apply_decision(
         %{"type" => "alternatives", "id" => placement_id, "alternatives_id" => group_id} =
           element,
         false,
         groups,
         decisions
       ) do
    group = Map.get(groups, group_id)
    decision = Map.get(decisions, placement_id)

    selected =
      case {experiment_group?(group), selected_option_id(decision)} do
        {true, option_id} when is_binary(option_id) ->
          keep_selected_alternative(element, option_id)

        {true, nil} ->
          keep_first_alternative(element)

        _ ->
          element
      end

    map_decision_children(selected, true, groups, decisions)
  end

  defp apply_decision(element, inside_alternatives?, groups, decisions),
    do: map_decision_children(element, inside_alternatives?, groups, decisions)

  defp map_decision_children(%{"children" => children} = element, inside?, groups, decisions)
       when is_list(children),
       do: Map.put(element, "children", apply_decisions(children, inside?, groups, decisions))

  defp map_decision_children(element, _inside?, _groups, _decisions), do: element

  defp report_invalid_nested_alternatives(element) do
    Logger.warning("Rendering invalid Alternatives placement nested within Alternatives",
      placement_id: Map.get(element, "id"),
      alternatives_id: Map.get(element, "alternatives_id")
    )

    Appsignal.increment_counter(@invalid_nested_metric, 1, %{reason: "nested_alternatives"})
  end

  @doc """
  Normalizes a persisted Alternatives strategy.

  Returns `{:ok, strategy}` for supported values and `{:error, :unsupported_strategy}`
  for unknown input so callers fail closed.
  """
  def normalize_strategy("upgrade_decision_point"), do: {:ok, "experiment_controlled"}
  def normalize_strategy("experiment_controlled"), do: {:ok, "experiment_controlled"}
  def normalize_strategy("select_all"), do: {:ok, "select_all"}
  def normalize_strategy("user_section_preference"), do: {:ok, "user_section_preference"}
  def normalize_strategy(_strategy), do: {:error, :unsupported_strategy}

  defp experiment_group?(%{strategy: strategy}),
    do: strategy in ["experiment_controlled", "upgrade_decision_point"]

  defp experiment_group?(_group), do: false

  defp selected_option_id(%{status: :assigned, option_id: option_id}), do: option_id
  defp selected_option_id(_decision), do: nil

  defp keep_selected_alternative(%{"children" => children} = element, option_id) do
    case Enum.find(children, &(Map.get(&1, "value") == option_id)) do
      %{} = selected -> Map.put(element, "children", [selected])
      _ -> element
    end
  end

  defp keep_first_alternative(%{"children" => [%{} = first | _]} = element),
    do: Map.put(element, "children", [first])

  defp keep_first_alternative(element), do: element

  defp normalize_strategy!(strategy) do
    case normalize_strategy(strategy) do
      {:ok, normalized} -> normalized
      {:error, :unsupported_strategy} -> raise ArgumentError, "unsupported Alternatives strategy"
    end
  end

  defp strategy("select_all"), do: SelectAllStrategy

  defp strategy("user_section_preference"), do: UserSectionPreferenceStrategy

  defp strategy("upgrade_decision_point"), do: ExperimentControlledStrategy
  defp strategy("experiment_controlled"), do: ExperimentControlledStrategy
end
