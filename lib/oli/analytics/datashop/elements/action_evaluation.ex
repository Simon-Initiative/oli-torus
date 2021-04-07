defmodule Oli.Analytics.Datashop.Elements.ActionEvaluation do
  @moduledoc """
  <action_evaluation current_hint_number="1" total_hints_available="1">HINT</action_evaluation>

  <action_evaluation>CORRECT</action_evaluation>
  """
  import XmlBuilder

  # For Hints
  def setup(%{
        current_hint_number: current_hint_number,
        total_hints_available: total_hints_available
      }) do
    element(
      :action_evaluation,
      %{
        current_hint_number: current_hint_number,
        total_hints_available: total_hints_available
      },
      "HINT"
    )
  end

  # For attempts
  def setup(%{part_attempt: part_attempt}) do
    element(:action_evaluation, correctness(part_attempt))
  end

  defp correctness(part_attempt) do
    if part_attempt.score == part_attempt.out_of do
      "CORRECT"
    else
      "INCORRECT"
    end
  end
end
