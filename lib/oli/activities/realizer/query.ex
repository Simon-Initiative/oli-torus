defmodule Oli.Activities.Realizer.Query do
  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Executor
  alias Oli.Activities.Realizer.Query.Paging

  @doc """
  Executes a paged activity bank query.

  Returns {:ok, %Result{}} when the query is successfully executed and returns
  {:error, error} otherwise.
  """
  def execute(%Logic{} = logic, %Source{} = source, %Paging{} = paging) do
    Builder.build(logic, source, paging, :paged)
    |> Executor.execute()
  end
end
