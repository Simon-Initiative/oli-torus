defmodule OliWeb.Api.VariableEvaluationController do
  @moduledoc """
  Endpoints to allow client-side invocation of the variable evalution service.
  """

  alias Oli.Activities.Transformers.VariableSubstitution.Strategy
  alias Oli.Activities.Model.Transformation
  import OliWeb.Api.Helpers

  use OliWeb, :controller

  def evaluate(conn, %{"data" => data, "count" => _count}) do
    assembled_transformer = %Transformation{id: 1, data: data, operation: :variable_substitution}

    case Strategy.provide_batch_context([assembled_transformer]) do
      {:ok, [evaluations]} -> json(conn, %{"result" => "success", "evaluations" => evaluations})
      _ -> error(conn, 500, "server error")
    end
  end
end
