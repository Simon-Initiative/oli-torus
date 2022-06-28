defmodule Oli.Activities.Transformers.Shuffle do
  alias Oli.Activities.Model.Transformation
  alias Oli.Activities.Transformers.Transformer

  @behaviour Transformer

  @impl Transformer
  def transform(model, %Transformation{path: path}, _context) do
    case Map.get(model, path) do
      nil ->
        {:error, :path_not_found}

      collection ->
        {:ok, Map.put(model, path, Enum.shuffle(collection))}
    end
  end

  @impl Transformer
  def provide_batch_context(_transformers) do
    {:ok, %{}}
  end
end
