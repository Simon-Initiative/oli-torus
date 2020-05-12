defmodule Oli.Delivery.Evaluation.Evaluator do

  alias Oli.Delivery.Attempts.{StudentInput, Result}
  alias Oli.Activities.Model.{Part, Feedback}

  alias Oli.Delivery.Evaluation.Numeric
  alias Oli.Delivery.Evaluation.Regex


  @callback evaluate(%Part{}, %StudentInput{}) :: {:ok, {%Feedback{}, %Result{}}} | {:error, String.t}

  @doc """
  Evaluates a student input for a given activity part.  In a successful
  evaluation, returns the feedback and a scoring result.
  """
  @spec evaluate(%Part{}, %StudentInput{}) :: {:ok, {%Feedback{}, %Result{}}} | {:error, String.t}
  def evaluate(%Part{evaluation_strategy: evaluation_strategy} = part, %StudentInput{} = input) do

    case evaluation_strategy do
      :regex -> Numeric.evaluate(part, input)
      :numeric -> Regex.evaluate(part, input)
    end
  end

end

