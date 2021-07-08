defmodule Oli.Activities.Realizer.Selection do
  @moduledoc """
  Represents a selection embedded within a page.
  """

  @derive Jason.Encoder
  @enforce_keys [:id, :count, :logic]
  defstruct [:id, :count, :logic]

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Selection
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Activities.Realizer.Query.Executor
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result

  @type t() :: %__MODULE__{
          id: String.t(),
          count: integer(),
          logic: %Logic{}
        }

  def parse(%{"count" => count, "id" => id, "logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, logic} -> {:ok, %Selection{id: id, count: count, logic: logic}}
      e -> e
    end
  end

  def parse(_) do
    {:error, "invalid selection"}
  end

  @doc """
  Fulfills a selection by querying the database for matching activities.

  Returns {:ok, %Result{}} when the selection is filled.

  Returns {:partial, %Result{}} when the query succeeds but less than the requested
  count of activities is returned.  This includes the case where zero activities are returned.

  Returns {:error, e} on a failure to execute the query.
  """
  def fulfill(%Selection{count: count, logic: logic}, %Source{} = source) do
    case Builder.build(logic, source, %Paging{limit: count, offset: 0}, :random)
         |> Executor.execute() do
      {:ok, %Result{rowCount: ^count} = result} ->
        {:ok, result}

      {:ok, result} ->
        {:partial, result}

      e ->
        e
    end
  end
end
