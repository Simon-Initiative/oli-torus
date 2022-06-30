defmodule Oli.Activities.Transformers.VariableSubstitution.Common do
  @doc """
  Replace the variables found in the model with their evaluations from the evaluation
  digest.
  """
  def replace_variables(model, evaluation_digest) do
    encoded = Jason.encode!(model)

    Enum.reduce(evaluation_digest, encoded, fn %{"variable" => v, "result" => r}, s ->
      r =
        case r do
          s when is_binary(s) -> s
          number -> Kernel.to_string(number)
        end

      String.replace(s, "@@#{v}@@", r)
    end)
    |> Jason.decode()
  end
end
