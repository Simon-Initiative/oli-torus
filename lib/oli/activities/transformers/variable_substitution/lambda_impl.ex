defmodule Oli.Activities.Transformers.VariableSubstitution.LambdaImpl do
  alias Oli.Activities.Transformers.VariableSubstitution.Strategy

  require Logger

  @behaviour Strategy

  @impl Strategy
  def substitute(_model, _evaluation_digest) do
    {:error, :not_implemented}
  end

  @impl Strategy
  def provide_batch_context(_transformers) do
    {:error, :not_implemented}
  end
end
