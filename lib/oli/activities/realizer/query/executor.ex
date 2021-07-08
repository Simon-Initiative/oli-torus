defmodule Oli.Activities.Realizer.Query.Executor do
  alias Oli.Activities.Realizer.Query.Result

  def execute({sql, params}) do
    case Ecto.Adapters.SQL.query(Oli.Repo, sql, params) do
      {:ok, %Postgrex.Result{rows: rows, columns: columns, num_rows: num_rows}} ->
        rows = Enum.map(rows, fn row -> to_record(row, columns) end)

        total_count =
          if num_rows > 0 do
            Map.get(hd(rows), "full_count", num_rows)
          else
            0
          end

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
    Enum.zip(columns, row)
    |> Map.new()
  end
end
