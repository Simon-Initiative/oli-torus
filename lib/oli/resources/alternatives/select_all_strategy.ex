defmodule Oli.Resources.Alternatives.SelectAllStrategy do
  alias Oli.Resources.Alternatives.AlternativesStrategyContext
  alias Oli.Resources.Alternatives.Selection

  @behaviour Oli.Resources.Alternatives.AlternativesStrategy

  @doc """
  Selects all alternatives
  """
  def select(%AlternativesStrategyContext{}, %{"children" => children}) do
    Enum.map(children, fn alt -> %Selection{alternative: alt} end)
  end
end
