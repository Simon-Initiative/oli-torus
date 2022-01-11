defmodule Oli.Activities.Transformers do
  alias Oli.Activities.Model
  alias Oli.Activities.Model.Transformation
  alias Oli.Activities.Transformers.Shuffle

  @doc """
  Transforms an unparsed activity model.

  When no transformations exist, or the resulting transformations had no effect, returns {:no_effect, original_model_parsed}

  Otherwise, this applies all transformations and returns {:ok, transformed_model} where
  `transformed_model` is the parsed model after mutation from transformations.

  If errors occur during parsing or transformation, returns {:error, e}
  """
  def apply_transforms(model) do
    case Model.parse(model) do
      {:ok, parsed_model} ->
        case Enum.count(parsed_model.transformations) do
          0 ->
            {:no_effect, parsed_model}

          _ ->
            Enum.reduce_while(parsed_model.transformations, {:ok, model}, fn t, {:ok, model} ->
              case apply_transform(model, t) do
                {:ok, transformed_model} -> {:cont, {:ok, transformed_model}}
                {:error, error} -> {:halt, {:error, error}}
              end
            end)
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp apply_transform(model, %Transformation{operation: :shuffle} = transformation) do
    Shuffle.transform(model, transformation)
  end

  defp apply_transform(_, _) do
    {:error, :transformation_not_implemented}
  end
end
