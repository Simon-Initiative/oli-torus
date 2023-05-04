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

  defp strategy("select_all"), do: SelectAllStrategy

  defp strategy("user_section_preference"), do: UserSectionPreferenceStrategy

  defp strategy("upgrade_decision_point"), do: DecisionPointStrategy
end
