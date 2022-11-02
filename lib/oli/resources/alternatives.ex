defmodule Oli.Resources.Alternatives do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.SelectAllStrategy
  alias Oli.Resources.Alternatives.UserSectionPreferenceStrategy

  @doc """
  Selects one or more alternatives using the element's specified strategy.

  Returns a list of `Oli.Resources.Alternatives.Selection` structs.
  """
  def select(
        %AlternativesStrategyContext{} = context,
        %{"strategy" => strategy_name} = alternatives_element
      ) do
    strategy(strategy_name).select(context, alternatives_element)
  end

  defp strategy("select_all"), do: SelectAllStrategy

  defp strategy("user_section_preference"), do: UserSectionPreferenceStrategy
end
