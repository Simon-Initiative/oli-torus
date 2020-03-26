defmodule Oli.Course.Utils do
  @chars "abcdefghijklmnopqrstuvwxyz" |> String.split("")
  @initial_version "1.0.0"

  def generate_slug(table, string) do
    unique_slug(
      table,
      slugify(string),
      [""] ++ ~w(_1 _2 _3 _4 _5) ++ [str(6), str(6), str(6)])
  end

  def str(length) do
    Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@chars) | acc]
    end) |> Enum.join("")
  end

  defp unique_slug(table, "", _suffixes) do "" end
  defp unique_slug(table, title, [suffix | remaining]) do
    candidate = title <> suffix

    query = Ecto.Adapters.SQL.query(
      Oli.Repo, "SELECT * FROM #{table} WHERE slug = $1;", [candidate])

    case query do
      {:ok, %{num_rows: 0 }} -> candidate
      {:ok, _results } -> unique_slug(table, title, remaining)
    end
  end
  defp unique_slug(table, _, []) do "" end

  defp slugify(nil) do "" end
  defp slugify(title) do
    String.downcase(title, :default) |> String.replace(" ", "_")
  end
end
