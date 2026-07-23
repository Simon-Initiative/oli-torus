defmodule Oli.Resources.Alternatives do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.SelectAllStrategy
  alias Oli.Resources.Alternatives.UserSectionPreferenceStrategy
  alias Oli.Resources.Alternatives.DecisionPointStrategy

  @doc """
  Selects one or more alternatives using the element's specified strategy.

  Returns a list of `Oli.Resources.Alternatives.Selection` structs.
  """
  def select(
        %AlternativesStrategyContext{alternative_groups_by_id: by_id} = context,
        %{"alternatives_id" => alternatives_id} = alternatives_element
      ) do
    strategy_name = Map.get(by_id, alternatives_id).strategy

    strategy(strategy_name).select(context, alternatives_element)
  end

  @doc """
  Prepares experiment-backed alternatives decisions for delivery before page rendering.

  Returns `{decisions_by_alternatives_id, attribution_payloads}`. The decision map
  is consumed by `select/2` during rendering so that delivery render does not need
  to assign learners or record exposure.
  """
  def prepare_delivery_decisions(%AlternativesStrategyContext{} = context, content) do
    DecisionPointStrategy.prepare_delivery_decisions(context, content)
  end

  defp strategy("select_all"), do: SelectAllStrategy

  defp strategy("user_section_preference"), do: UserSectionPreferenceStrategy

  defp strategy("upgrade_decision_point"), do: DecisionPointStrategy
end
