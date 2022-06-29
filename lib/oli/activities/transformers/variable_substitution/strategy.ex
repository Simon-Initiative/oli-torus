defmodule Oli.Activities.Transformers.VariableSubstitution.Strategy do
  @doc """
  Performs variable subsitution on a model.
  """
  @callback substitute(map(), map()) :: {:ok, map()} | {:error, term()}

  @callback provide_batch_context(list()) :: {:ok, list()} | {:error, term()}

  @doc """
  Does the dynamic dispatch based on configured provider.
  """
  def substitute(model, data) do
    module = Application.fetch_env!(:oli, :variable_substitution)[:dispatcher]
    apply(module, :substitute, [model, data])
  end

  def provide_batch_context(transformers) do
    module = Application.fetch_env!(:oli, :variable_substitution)[:dispatcher]
    apply(module, :provide_batch_context, [transformers])
  end
end
