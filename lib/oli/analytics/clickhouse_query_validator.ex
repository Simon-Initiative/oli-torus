defmodule Oli.Analytics.ClickhouseQueryValidator do
  @moduledoc """
  Validates custom ClickHouse SQL queries for analytics dashboards.

  These checks enforce read-only SELECT queries scoped to a specific
  section_id or project_id to prevent data leakage and unsafe commands.
  """

  @forbidden_keywords ~w(
    insert update delete alter create drop truncate optimize attach detach rename exchange
    grant revoke set use kill system
  )

  @doc """
  Validates a custom SQL query for the given scope field and value.

  Returns :ok when the query is a single SELECT statement and includes a
  section_id/project_id predicate with the expected value.
  """
  def validate_custom_query(query, scope_field, scope_value)
      when is_binary(query) and scope_field in [:section_id, :project_id] and
             is_integer(scope_value) do
    normalized_for_keywords = normalize_query(query, strip_strings: true)
    normalized_for_predicates = normalize_query(query, strip_strings: false)

    with :ok <- ensure_single_statement(normalized_for_keywords),
         :ok <- ensure_select_only(normalized_for_keywords),
         :ok <- ensure_no_forbidden_keywords(normalized_for_keywords),
         :ok <- ensure_scope_filter(normalized_for_predicates, scope_field, scope_value) do
      :ok
    end
  end

  def validate_custom_query(_, _, _), do: {:error, "Invalid query or scope"}

  defp normalize_query(query, opts) do
    query
    |> strip_comments()
    |> maybe_strip_strings(opts)
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp strip_comments(query) do
    query
    |> String.replace(~r/\/\*.*?\*\//s, " ")
    |> String.replace(~r/--.*$/m, " ")
    |> String.replace(~r/\/\/.*$/m, " ")
  end

  defp maybe_strip_strings(query, %{strip_strings: true}) do
    query
    |> String.replace(~r/'([^']|'')*'/, "''")
    |> String.replace(~r/\"([^\"]|\"\")*\"/, "\"\"")
  end

  defp maybe_strip_strings(query, _opts), do: query

  defp ensure_single_statement(normalized_query) do
    case String.split(normalized_query, ";") do
      [single] ->
        if String.trim(single) != "" do
          :ok
        else
          {:error, "Query must contain a single SELECT statement"}
        end

      [single, ""] ->
        if String.trim(single) != "" do
          :ok
        else
          {:error, "Query must contain a single SELECT statement"}
        end

      _ ->
        {:error, "Query must contain a single SELECT statement"}
    end
  end

  defp ensure_select_only(normalized_query) do
    starts_with_select = Regex.match?(~r/^\s*(with|select)\b/, normalized_query)
    contains_select = Regex.match?(~r/\bselect\b/, normalized_query)
    starts_with_explain = Regex.match?(~r/^\s*explain\b/, normalized_query)

    if starts_with_select and contains_select and not starts_with_explain do
      :ok
    else
      {:error, "Only SELECT statements are allowed"}
    end
  end

  defp ensure_no_forbidden_keywords(normalized_query) do
    regex = forbidden_keyword_regex()

    if Regex.match?(regex, normalized_query) do
      {:error, "Query contains disallowed SQL keywords"}
    else
      :ok
    end
  end

  defp forbidden_keyword_regex do
    pattern =
      @forbidden_keywords
      |> Enum.map(&Regex.escape/1)
      |> Enum.join("|")

    Regex.compile!("\\b(" <> pattern <> ")\\b")
  end

  defp ensure_scope_filter(normalized_query, scope_field, scope_value) do
    field = Atom.to_string(scope_field)
    value = Integer.to_string(scope_value)

    if scope_predicate_present?(normalized_query, field, value) do
      :ok
    else
      if scope_field_mentioned?(normalized_query, field) do
        {:error, "Query must filter results to the current #{field} (#{field} = #{value})"}
      else
        {:error, "Query must include a WHERE clause filtering by #{field} = #{value}"}
      end
    end
  end

  defp scope_predicate_present?(normalized_query, field, value) do
    Enum.any?(scope_predicate_patterns(field, value), fn pattern ->
      Regex.match?(pattern, normalized_query)
    end)
  end

  defp scope_field_mentioned?(normalized_query, field) do
    Regex.match?(~r/\b(?:[a-z_][\w]*\.)?#{field}\b/, normalized_query)
  end

  defp scope_predicate_patterns(field, value) do
    alias_prefix = "(?:[a-z_][\\w]*\\.)?"
    field_pattern = "\\b" <> alias_prefix <> field <> "\\b"
    value_pattern = "\\b" <> value <> "\\b"

    equality_patterns = [
      "\\b(where|prewhere)\\b[^;]*?" <> field_pattern <> "\\s*(=|==)\\s*" <> value_pattern,
      "\\b(where|prewhere)\\b[^;]*?" <> field_pattern <> "\\s*(=|==)\\s*'" <> value <> "'",
      "\\b(where|prewhere)\\b[^;]*?" <> field_pattern <> "\\s*(=|==)\\s*\"" <> value <> "\"",
      "\\b(where|prewhere)\\b[^;]*?" <>
        field_pattern <>
        "\\s*(=|==)\\s*(?:toint(?:8|16|32|64)?|touint(?:8|16|32|64)?)\\s*\\(\\s*" <>
        value <> "\\s*\\)"
    ]

    in_patterns = [
      "\\b(where|prewhere)\\b[^;]*?" <>
        field_pattern <>
        "\\s+in\\s*\\([^)]*" <>
        value_pattern <> "[^)]*\\)",
      "\\b(where|prewhere)\\b[^;]*?" <>
        field_pattern <>
        "\\s+in\\s*\\[[^\]]*" <>
        value_pattern <> "[^\]]*\\]"
    ]

    (equality_patterns ++ in_patterns)
    |> Enum.map(&Regex.compile!/1)
  end
end
