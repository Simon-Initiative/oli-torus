defmodule Oli.Delivery.Evaluation.Numeric do

  alias Oli.Delivery.Evaluation.Evaluator
  alias Oli.Delivery.Attempts.{StudentInput, Result}
  alias Oli.Activities.Model.{Part}

  @behaviour Oli.Delivery.Evaluation.Evaluator

  @impl Evaluator
  def evaluate(%Part{} = part, %StudentInput{input: input}) do

    # Placeholder implementation
    if (input < 0) do
      {:ok, {hd(part.responses).feedback, %Result{score: 1, out_of: 1}}}
    else
      {:ok, {hd(part.responses).feedback, %Result{score: 0, out_of: 1}}}
    end
  end

end

