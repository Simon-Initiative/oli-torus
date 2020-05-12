defmodule Oli.Delivery.Evaluation  do

  @eval_strategies Enum.map([:regex, :numeric], fn a -> {a, Atom.to_string(a)} end)
    |> Map.new

  @eval_strategies_from_string Map.keys(@eval_strategies)
    |> Enum.map(fn a -> {Atom.to_string(a), a} end)
    |> Map.new

  @spec parse_strategy(String.t) :: {:ok, :regex | :numeric} | {:error, :invalid}
  def parse_strategy(strategy) do

    if Map.has_key?(@eval_strategies_from_string, strategy) do
      {:ok, Map.get(@eval_strategies_from_string, strategy)}
    else
      {:error, :invalid_strategy}
    end
  end

end
