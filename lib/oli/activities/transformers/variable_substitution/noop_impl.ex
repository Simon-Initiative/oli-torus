defmodule Oli.Activities.Transformers.VariableSubstitution.NoOpImpl do
  alias Oli.Activities.Transformers.VariableSubstitution.Strategy
  alias Oli.Activities.Transformers.VariableSubstitution.Common

  @behaviour Strategy

  @impl Strategy
  def substitute(model, evaluation_digest) do
    Common.replace_variables(model, evaluation_digest)
  end

  @impl Strategy
  def provide_batch_context(transformers) do
    {:ok, Enum.map(transformers, fn _ -> %{} end)}
  end
end
