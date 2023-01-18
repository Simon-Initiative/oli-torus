defmodule Oli.Resources.Alternatives.AlternativesStrategy do
  @moduledoc """
  Behavior that defines an alternatives strategy.

  An alternatives strategy takes an alternatives element and determines
  which alternative(s) to return using the element's specified strategy.
  """
  alias Oli.Resources.Alternatives.AlternativesStrategyContext

  @callback select(%AlternativesStrategyContext{}, any()) :: [any()]
end
