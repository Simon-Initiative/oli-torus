defmodule Oli.GenAI.Agent.Tool do
  @moduledoc "Generic tool behaviour (broker calls implementers)."
  @callback call(name :: String.t(), args :: map(), ctx :: map()) ::
              {:ok, %{content: term(), token_cost: non_neg_integer()}} | {:error, term()}
end