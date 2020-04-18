defmodule Oli.Authoring.Course.Utils do
  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("")

  def generate_slug(table, string) do

    suffixes = [
      fn -> "" end,
      fn -> str(5) end,
      fn -> str(5) end,
      fn -> str(5) end,
      fn -> str(5) end,
      fn -> str(10) end,
      fn -> str(10) end,
      fn -> str(10) end,
      fn -> str(10) end,
      fn -> str(10) end,
    ]

    unique_slug(table, slugify(string), suffixes)
  end

  def str(length) do
    Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@chars) | acc]
    end) |> Enum.join("")
  end

  defp unique_slug(_table, "", _suffixes), do: ""
  defp unique_slug(table, title, [suffix | remaining]) do
    candidate = title <> suffix.()

    query = Ecto.Adapters.SQL.query(
      Oli.Repo, "SELECT * FROM #{table} WHERE slug = $1;", [candidate])

    case query do
      {:ok, %{num_rows: 0 }} -> candidate
      {:ok, _results } -> unique_slug(table, title, remaining)
    end
  end
  defp unique_slug(_table, _, []) do "" end

  defp slugify(nil), do: ""
  defp slugify(title), do: String.downcase(title, :default) |> String.replace(" ", "_")
end
