defmodule Oli.Activities.Transformers.Transformer do

  alias Oli.Activities.Model.Transformation

  @callback transform(map(), %Transformation{}) :: {:ok, map()} | {:error, any}

end
