defmodule Oli.Resources.Alternatives.SelectAllStrategy do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Selects all alternatives
  """
  def select(%AlternativesStrategyContext{}, %{"children" => children}) do
    children
  end
end
