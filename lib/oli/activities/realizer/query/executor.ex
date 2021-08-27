defmodule Oli.Activities.Realizer.Query.Executor do
  @moduledoc """
  Executes the queries built by `Oli.Activities.Realizer.Query.Builder`.
  """

  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Repo

  def execute({sql, params}) do
    case Ecto.Adapters.SQL.query(Oli.Repo, sql, params) do
      {:ok, %Postgrex.Result{rows: rows, columns: columns, num_rows: num_rows}} ->
        total_count =
          if num_rows > 0 do
            case Enum.find_index(columns, fn c -> c == "full_count" end) do
              nil -> num_rows
              index -> Enum.at(hd(rows), index)
            end
          else
            0
          end

        rows = Enum.map(rows, fn row -> to_record(row, columns) end)

        {:ok,
         %Result{
           rows: rows,
           rowCount: num_rows,
           totalCount: total_count
         }}

      e ->
        e
    end
  end

  defp to_record(row, columns) do
    kvs =
      Enum.zip(columns, row)
      |> Enum.filter(fn {k, _} -> k != "full_count" end)
      |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)

    Repo.load(Oli.Resources.Revision, kvs)
  end
end
