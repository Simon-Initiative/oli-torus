defmodule OliWeb.ManualGrading.BrowseParams do
  @moduledoc """
  Total parser for the manual scoring URL params: it never raises, and any value whose shape is
  not the expected one becomes the unfiltered default.
  """

  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias OliWeb.Common.Params

  @max_bigint 9_223_372_036_854_775_807

  @doc "Builds the browse options from the URL params, normalizing every field."
  def browse_options(params) do
    %BrowseOptions{
      text_search: text_search(params),
      user_ids: id_list(params, "selected_user_ids", "user_id"),
      activity_ids: id_list(params, "selected_activity_ids", "activity_id"),
      page_ids: id_list(params, "selected_page_ids", "page_id"),
      graded: graded(params)
    }
  end

  @doc """
  Reads `key` as a JSON list of positive bigints (integers or decimal strings), deduplicated and
  sorted; invalid elements are dropped and any other shape is `[]`. When `key` is absent and
  `legacy_key` is given, its scalar value is read as a one-element list.
  """
  def id_list(params, key, legacy_key \\ nil) do
    cond do
      Map.has_key?(params, key) -> params |> Params.get_list_param(key, []) |> normalize_ids()
      is_nil(legacy_key) -> []
      true -> params |> Map.get(legacy_key) |> List.wrap() |> normalize_ids()
    end
  end

  @table_param_keys ~w(sort_by sort_order text_search selected_user_ids selected_activity_ids selected_page_ids graded offset)
  @legacy_lists [
    {"user_id", "selected_user_ids"},
    {"activity_id", "selected_activity_ids"},
    {"page_id", "selected_page_ids"}
  ]

  @doc """
  The table params present in the URL, to carry on links to the scoring page and back. A legacy
  scalar filter (`user_id=5`) is carried as its modern list (`selected_user_ids=[5]`).
  """
  def table_params(params) do
    base = Map.take(params, @table_param_keys)

    Enum.reduce(@legacy_lists, base, fn {legacy, modern}, acc ->
      case Map.has_key?(params, legacy) and not Map.has_key?(params, modern) do
        true -> Map.put(acc, modern, Jason.encode!(id_list(params, modern, legacy)))
        false -> acc
      end
    end)
  end

  @doc "Reads `text_search` as a string; any other shape is `\"\"`."
  def text_search(params) do
    case Map.get(params, "text_search") do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  @doc "Reads `graded` as `true`, `false` or `nil` (no filter)."
  def graded(params), do: Params.get_boolean_param(params, "graded", nil)

  @sort_fields ~w(user activity_title attempt_number page_title resource_attempt_number activity_type_id graded date_submitted)a
  @sort_fields_by_name Map.new(@sort_fields, &{Atom.to_string(&1), &1})

  @doc "Reads `sort_by` / `sort_order` within the table's allowlist; defaults to date submitted, descending."
  def sorting(params) do
    %Oli.Repo.Sorting{
      field: Map.get(@sort_fields_by_name, Map.get(params, "sort_by"), :date_submitted),
      direction:
        case Map.get(params, "sort_order") do
          "asc" -> :asc
          _ -> :desc
        end
    }
  end

  @doc """
  Reads `offset` as an integer from 0 to the largest bigint; a larger value becomes that bigint
  (past every page) and anything else is `0`.
  """
  def offset(params) do
    case Map.get(params, "offset") do
      value when is_integer(value) and value >= 0 -> min(value, @max_bigint)
      value when is_binary(value) -> value |> parse_decimal() |> max(0) |> min(@max_bigint)
      _ -> 0
    end
  end

  @doc "Parses a route `attempt_id` into `{:ok, id}` for a positive bigint, `:error` otherwise."
  def attempt_id(value) do
    case normalize_ids([value]) do
      [id] -> {:ok, id}
      [] -> :error
    end
  end

  defp normalize_ids(values) when is_list(values) do
    values |> Enum.flat_map(&id_or_empty/1) |> Enum.uniq() |> Enum.sort()
  end

  defp id_or_empty(value) when is_integer(value) and value >= 1 and value <= @max_bigint,
    do: [value]

  defp id_or_empty(value) when is_binary(value), do: value |> parse_decimal() |> id_or_empty()
  defp id_or_empty(_), do: []

  defp parse_decimal(value) do
    case Regex.match?(~r/\A\d+\z/, value) do
      true -> value |> String.trim_leading("0") |> digits_to_integer()
      false -> -1
    end
  end

  # More significant digits than the largest bigint (19) is past the range without converting:
  # String.to_integer/1 raises on a long enough string and costs more than linear time before that.
  defp digits_to_integer(""), do: 0
  defp digits_to_integer(digits) when byte_size(digits) > 19, do: @max_bigint + 1
  defp digits_to_integer(digits), do: String.to_integer(digits)
end
