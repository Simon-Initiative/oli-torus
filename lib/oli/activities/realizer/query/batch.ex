defmodule Oli.Activities.Realizer.Query.Batch do
  @moduledoc """
  Executes multiple realizer queries in a single database round trip.
  """

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Query.Builder
  alias Oli.Activities.Realizer.Query.Paging
  alias Oli.Activities.Realizer.Query.Result
  alias Oli.Activities.Realizer.Query.Source
  alias Oli.Repo
  alias Oli.Resources.Revision

  @type query_id :: String.t()
  @type query_spec :: {query_id(), %Logic{}, Source.t()}

  @doc """
  Executes query specs and returns `%Result{}` values keyed by query id.
  """
  @spec execute([query_spec()], Paging.t(), :paged | :random) ::
          {:ok, %{query_id() => %Result{}}} | {:error, term()}
  def execute([], %Paging{}, view_type) when view_type in [:paged, :random], do: {:ok, %{}}

  def execute(query_specs, %Paging{} = paging, view_type)
      when is_list(query_specs) and view_type in [:paged, :random] do
    with {:ok, {sql, params}} <- build(query_specs, paging, view_type),
         {:ok, %Postgrex.Result{} = result} <- Ecto.Adapters.SQL.query(Repo, sql, params) do
      {:ok, results_by_query_id(result, query_specs)}
    end
  end

  defp build(query_specs, paging, view_type) do
    query_specs
    |> Enum.reduce({[], [], 0}, fn {query_id, %Logic{} = logic, %Source{} = source},
                                   {branches, param_groups, param_count} ->
      {sql, sql_params} = Builder.build(logic, source, paging, view_type)

      query_id_param = param_count + 1
      shifted_sql = shift_sql_parameters(sql, query_id_param)

      branch =
        "SELECT $#{query_id_param}::text AS query_id, query_rows.* FROM (#{shifted_sql}) AS query_rows"

      {[branch | branches], [[query_id | sql_params] | param_groups],
       param_count + 1 + length(sql_params)}
    end)
    |> then(fn {branches, param_groups, _param_count} ->
      params =
        param_groups
        |> Enum.reverse()
        |> Enum.flat_map(& &1)

      {:ok, {branches |> Enum.reverse() |> Enum.join(" UNION ALL "), params}}
    end)
  end

  defp shift_sql_parameters(sql, offset) do
    Regex.replace(~r/\$(\d+)/, sql, fn _match, number ->
      "$#{String.to_integer(number) + offset}"
    end)
  end

  defp results_by_query_id(%Postgrex.Result{rows: rows, columns: columns}, query_specs) do
    query_id_index = Enum.find_index(columns, &(&1 == "query_id"))
    count_index = Enum.find_index(columns, &(&1 == "full_count"))
    revision_column_indexes = revision_column_indexes(columns)

    empty_results =
      Map.new(query_specs, fn {query_id, %Logic{}, %Source{}} ->
        {query_id, %Result{rows: [], rowCount: 0, totalCount: 0}}
      end)

    rows
    |> Enum.reduce(empty_results, fn row, acc ->
      query_id = Enum.at(row, query_id_index)
      revision = revision_from_row(row, revision_column_indexes)
      full_count = if count_index, do: Enum.at(row, count_index), else: 0

      Map.update!(acc, query_id, fn %Result{} = result ->
        %Result{
          result
          | rows: [revision | result.rows],
            rowCount: result.rowCount + 1,
            totalCount: full_count
        }
      end)
    end)
    |> Map.new(fn {query_id, %Result{} = result} ->
      {query_id, %Result{result | rows: Enum.reverse(result.rows)}}
    end)
  end

  defp revision_column_indexes(columns) do
    columns
    |> Enum.with_index()
    |> Enum.reject(fn {column, _index} -> column in ["query_id", "full_count"] end)
    |> Enum.map(fn {column, index} -> {index, String.to_existing_atom(column)} end)
  end

  defp revision_from_row(row, revision_column_indexes) do
    revision_column_indexes
    |> Enum.map(fn {index, column} -> {column, Enum.at(row, index)} end)
    |> then(&Repo.load(Revision, &1))
  end
end
