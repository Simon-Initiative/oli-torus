defmodule Oli.Utils.Slug do
  @chars "abcdefghijklmnopqrstuvwxyz1234567890" |> String.split("", trim: true)

  @doc """
  Updates the slug from the title for a table if the title has not
  been set or if it has changed.
  """
  def update_on_change(changeset, table) do
    case changeset.valid? do
      # We only have to consider changing the slug if this is a valid changeset
      true ->
        case Ecto.Changeset.get_change(changeset, :title) do
          # if we aren't changing the title, we don't have to even consider
          # changing the slug
          nil ->
            changeset

          # if we are changing the title, we need to consider whether or not
          # this is for a new revision or this is an update for an existing one
          title ->
            case Ecto.Changeset.get_change(changeset, :id) do
              # This is a changeset for the creation of a new revision
              nil -> handle_creation(changeset, table, title)
              # This is a changeset for an update
              _ -> handle_update(changeset, table, title)
            end
        end

      _ ->
        changeset
    end
  end

  def handle_creation(changeset, table, title) do
    # get the previous revision id out of the changeset
    case Ecto.Changeset.get_change(changeset, :previous_revision_id) do
      # if there isn't a previous, we must set the slug
      nil ->
        Ecto.Changeset.put_change(changeset, :slug, generate(table, title))

      # There is a previous, so fetch it
      id ->
        case Ecto.Adapters.SQL.query(
               Oli.Repo,
               "SELECT slug, title FROM #{table} WHERE id = $1;",
               [id]
             ) do
          # If the previous slug's title matches the current title, we reuse
          # the slug from that previous
          {:ok, %{rows: [[slug, ^title]]}} -> Ecto.Changeset.put_change(changeset, :slug, slug)
          # Otherwise, create a new slug
          _ -> Ecto.Changeset.put_change(changeset, :slug, generate(table, title))
        end
    end
  end

  def get_unique_prefix(table) do
    prefix = random_string(5)

    query =
      Ecto.Adapters.SQL.query(
        Oli.Repo,
        "SELECT * FROM #{table} WHERE slug like '#{prefix}%';",
        []
      )

    case query do
      {:ok, %{num_rows: 0}} -> prefix
      {:ok, _results} -> get_unique_prefix(table)
    end
  end

  def handle_update(changeset, table, title) do
    Ecto.Changeset.put_change(changeset, :slug, generate(table, title))
  end

  @doc """
  Generates a slug once, but then guarantee that it never changes
  on future title changes.
  """
  def update_never(changeset, table) do
    case changeset.valid? do
      true ->
        case Ecto.Changeset.get_field(changeset, :slug) do
          nil ->
            Ecto.Changeset.put_change(
              changeset,
              :slug,
              generate(table, Ecto.Changeset.get_field(changeset, :title))
            )

          _ ->
            changeset
        end

      _ ->
        changeset
    end
  end

  def update_never_seedless(changeset, table) do
    if not changeset.valid? or !is_nil(Ecto.Changeset.get_field(changeset, :slug)) do
      changeset
    else
      Ecto.Changeset.put_change(
        changeset,
        :slug,
        generate_seedless(table)
      )
    end
  end

  def generate_seedless(table) do
    unique_slug(table, fn -> random_string(5) end)
  end

  @doc """
  Generates a unique slug or slugs for the table using the title or titles provided
  """
  def generate(table, titles) when is_list(titles) do
    # Ensure no repeated titles
    {titles, _, _} =
      Enum.reduce(titles, {[], MapSet.new(), 1}, fn title, {titles, titles_map_set, index} ->
        slugified_title = slugify(title)

        case MapSet.member?(titles_map_set, slugified_title) do
          false ->
            {[slugified_title | titles], MapSet.put(titles_map_set, slugified_title), index}

          _ ->
            slugified_title = "#{slugified_title}_#{suffix_from_number(index)}"
            {[slugified_title | titles], MapSet.put(titles_map_set, slugified_title), index + 1}
        end
      end)

    unique_slugs(table, Enum.reverse(titles), 0, 10)
  end

  def generate(table, title) do
    unique_slug(table, slugify(title), 0, 10)
  end

  defp suffix_from_number(number) do
    @chars
    |> Enum.take_random(4)
    |> Enum.concat([Integer.to_string(abs(number))])
    |> Enum.join()
  end

  @doc """
  Given a title and an attempt number, generates a slug candidate that might not be unique.
  """
  def generate_nth(title, n) do
    slugify(title) <> suffix(n)
  end

  def str(length) do
    "_" <> random_string(length)
  end

  def random_string(length) do
    Enum.reduce(1..length, [], fn _i, acc ->
      [Enum.random(@chars) | acc]
    end)
    |> Enum.join("")
  end

  def slug_with_prefix(prefix, title) do
    "#{prefix}_#{slugify(title)}_#{random_string(5)}"
  end

  def slugify(nil), do: ""

  def slugify(title) do
    case String.downcase(title, :default)
         |> String.trim()
         |> String.replace(" ", "_")
         |> alpha_numeric_only()
         |> URI.encode_www_form()
         |> String.slice(0, 30) do
      # A page title that only contains non-alphanumeric characters will
      # generate a slug that is empty. This is not allowed, so we generate
      # a random slug instead.
      "" ->
        random_string(10)

      otherwise ->
        otherwise
    end
  end

  defp unique_slug(table, generate_candidate) when is_function(generate_candidate) do
    _unique_slug_helper(table, generate_candidate, 0)
  end

  defp unique_slug(_table, "", _attempt, _max_attempts), do: ""
  defp unique_slug(_table, _title, attempt, max_attempts) when attempt == max_attempts, do: ""

  defp unique_slug(table, title, attempt, max_attempts) do
    candidate = title <> suffix(attempt)

    case check_unique_slug(table, candidate) do
      {:ok, slug} -> slug
      :error -> unique_slug(table, title, attempt + 1, max_attempts)
    end
  end

  defp unique_slugs(_table, [], _attempt, _max_attempts), do: []

  defp unique_slugs(_table, _slugified_titles, attempt, max_attempts)
       when attempt == max_attempts,
       do: []

  defp unique_slugs(table, slugified_titles, attempt, max_attempts) do
    candidates = Enum.map(slugified_titles, &(&1 <> suffix(attempt)))

    case check_unique_slugs(table, candidates) do
      {:ok, candidates} ->
        candidates

      :error ->
        unique_slugs(table, slugified_titles, attempt + 1, max_attempts)
    end
  end

  defp _unique_slug_helper(table, generate_candidate, count) do
    if count > 100 do
      ""
    else
      case check_unique_slug(table, generate_candidate.()) do
        {:ok, slug} -> slug
        :error -> _unique_slug_helper(table, generate_candidate, count + 1)
      end
    end
  end

  defp check_unique_slug(table, candidate) do
    query =
      Ecto.Adapters.SQL.query(
        Oli.Repo,
        "SELECT * FROM #{table} WHERE slug = $1;",
        [candidate]
      )

    case query do
      {:ok, %{num_rows: 0}} -> {:ok, candidate}
      {:ok, _results} -> :error
    end
  end

  defp check_unique_slugs(table, candidates) do
    query =
      Ecto.Adapters.SQL.query(
        Oli.Repo,
        "SELECT * FROM #{table} WHERE slug = ANY($1);",
        [candidates]
      )

    case query do
      {:ok, %{num_rows: 0}} -> {:ok, candidates}
      {:ok, _results} -> :error
    end
  end

  def alpha_numeric_only(str) do
    String.replace(str, ~r/[^A-Za-z0-9_]+/, "")
  end

  defp suffix(0), do: ""
  defp suffix(n) when n < 5, do: str(5)
  defp suffix(_), do: str(10)
end
