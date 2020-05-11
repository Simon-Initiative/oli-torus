defmodule Oli.Activities.Transformers do


  alias Oli.Activities.Model
  alias Oli.Activities.Model.Transformation
  alias Oli.Activities.Transformers.Shuffle

  @doc """
  Transforms an unparsed activity model.
  """
  @spec apply_transforms(map()) :: {:ok, map()} | {:error, any}
  def apply_transforms(model) do

    case Model.parse(model) do
      {:ok, parsed_model} -> Enum.reduce_while(parsed_model.transformations, {:ok, model}, fn t, {:ok, model} ->
        case apply_transform(model, t) do
          {:ok, transformed_model} -> {:cont, {:ok, transformed_model}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end)
      {:error, error} -> {:error, error}
    end

  end

  defp apply_transform(model, %Transformation{operation: :shuffle} = transformation) do
    Shuffle.transform(model, transformation)
  end

  defp apply_transform(_, _) do
    {:error, :transformation_not_implemented}
  end

end
