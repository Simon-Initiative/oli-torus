defmodule Oli.Utils.Database do
  alias Oli.Repo
  require Logger

  def explain_sql(query, params, opts \\ []) when is_binary(query) do
    opts = put_defaults(opts)

    sql = "EXPLAIN (#{analyze_to_sql(opts[:analyze])}, #{format_to_sql(opts[:format])}) #{query}"

    {:error, explain} =
      Repo.transaction(fn ->
        Repo
        |> Ecto.Adapters.SQL.query!(sql, params)
        |> Repo.rollback()
      end)

    if opts[:log_output] do
      log_output(explain, opts[:format])
      query
    else
      explain
    end
  end

  def explain(query, opts \\ []) do
    opts = put_defaults(opts)

    {sql, params} = Ecto.Adapters.SQL.to_sql(opts[:op], Repo, query)

    sql = "EXPLAIN (#{analyze_to_sql(opts[:analyze])}, #{format_to_sql(opts[:format])}) #{sql}"

    {:error, explain} =
      Repo.transaction(fn ->
        Repo
        |> Ecto.Adapters.SQL.query!(sql, params)
        |> Repo.rollback()
      end)

    if opts[:log_output] do
      log_output(explain, opts[:format])
      query
    else
      explain
    end
  end

  defp put_defaults(opts) do
    opts
    |> Keyword.put_new(:op, :all)
    |> Keyword.put_new(:format, :json)
    |> Keyword.put_new(:analyze, false)
    |> Keyword.put_new(:log_output, true)
  end

  defp log_output(results, :text) do
    results
    |> Map.get(:rows)
    |> Enum.join("\n")
    |> Logger.warn()
  end

  defp log_output(results, :json) do
    results
    |> Map.get(:rows)
    |> List.first()
    |> Jason.encode!(pretty: true)
    |> Logger.warn()
  end

  defp log_output(results, :yaml) do
    results
    |> Map.get(:rows)
    |> List.first()
    |> Logger.warn()
  end

  defp format_to_sql(:text), do: "FORMAT TEXT"
  defp format_to_sql(:json), do: "FORMAT JSON"
  defp format_to_sql(:yaml), do: "FORMAT YAML"

  defp analyze_to_sql(true), do: "ANALYZE true"
  defp analyze_to_sql(false), do: "ANALYZE false"
end
