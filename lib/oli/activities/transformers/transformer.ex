defmodule Oli.Activities.Transformers.Transformer do
  alias Oli.Activities.Model.Transformation

  @callback transform(map(), %Transformation{}, map()) :: {:ok, map()} | {:error, any}

  @callback provide_batch_context([%Transformation{}]) :: {:ok, map()} | {:error, any}
end
