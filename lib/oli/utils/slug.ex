defmodule Oli.Utils.Slug do

  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("")

  def maybe_update_slug(changeset, table) do
    case changeset.valid? do
      true ->
        case Ecto.Changeset.get_change(changeset, :title) do
          nil -> case Ecto.Changeset.get_field(changeset, :title) do
            nil -> changeset
            title -> Ecto.Changeset.put_change(changeset, :slug, generate(table, title))
          end
          title -> Ecto.Changeset.put_change(changeset, :slug, generate(table, title))
        end

      _ -> changeset
    end
  end

  defp generate(table, title) do

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

    unique_slug(table, slugify(title), suffixes)
  end

  def str(length) do
    "_" <> (Enum.reduce((1..length), [], fn (_i, acc) ->
      [Enum.random(@chars) | acc]
    end) |> Enum.join(""))
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
  defp slugify(title) do
    String.downcase(title, :default)
      |> String.trim()
      |> String.replace(" ", "_")
      |> URI.encode_www_form()
      |> String.slice(0, 30)
  end
end
