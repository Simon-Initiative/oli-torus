defmodule Oli.Delivery.Evaluation.LegacyInput do
  @moduledoc false

  alias Oli.Delivery.Evaluation.EvaluationContext

  @spec submitted_value(:input | {:input, String.t()}, EvaluationContext.t()) :: String.t()
  def submitted_value(:input, %EvaluationContext{input: input}) when is_binary(input) do
    Oli.Utils.normalize_whitespace(input)
  end

  def submitted_value(:input, %EvaluationContext{}), do: ""

  def submitted_value({:input, ref}, %EvaluationContext{input: input}) do
    try do
      input
      |> Poison.decode!()
      |> Map.get(ref, "")
      |> normalize_value()
    rescue
      _ ->
        # `input_ref_*` rules are scoped to structured multi-input payloads. A
        # malformed payload should not be treated as if the whole submission
        # belonged to that one input.
        ""
    end
  end

  defp normalize_value(value) when is_binary(value), do: Oli.Utils.normalize_whitespace(value)
  defp normalize_value(value), do: value |> to_string() |> Oli.Utils.normalize_whitespace()
end
