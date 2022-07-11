defmodule Oli.Activities.Transformers.VariableSubstitution do
  alias Oli.Activities.Transformers.Transformer
  alias Oli.Activities.Transformers.VariableSubstitution.Strategy

  @behaviour Transformer

  @impl Transformer
  def transform(model, _, evaluated_variables) do
    Strategy.substitute(model, evaluated_variables)
  end

  @impl Transformer
  def provide_batch_context(transformers) do
    Strategy.provide_batch_context(transformers)
  end
end
