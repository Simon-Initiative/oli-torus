defmodule OliWeb.Admin.BrowseFilters do
  @moduledoc """
  Shared helpers for managing browse filter state across the admin lists.

  The module provides utilities to:

    * Normalize filter parameters coming from forms
    * Parse query parameters into a typed filter state
    * Convert the filter state back into query parameters
    * Produce filter metadata such as active counts or tag identifiers
  """

  alias Oli.Tags

  @type tag_item :: %{id: integer(), name: String.t()}

  defmodule State do
    @moduledoc false
    defstruct date_field: :inserted_at,
              date_from: nil,
              date_to: nil,
              tags: [],
              visibility: nil,
              published: nil,
              status: nil,
              institution_id: nil
  end

  @type t :: %State{
          date_field: atom(),
          date_from: Date.t() | nil,
          date_to: Date.t() | nil,
          tags: [tag_item()],
          visibility: atom() | nil,
          published: boolean() | nil,
          status: atom() | nil,
          institution_id: integer() | nil
        }

  @date_field_default :inserted_at
  @param_prefix "filter_"

  @spec default(Keyword.t()) :: t()
  def default(_opts \\ []), do: %State{}

  @spec normalize_form_params(map()) :: map()
  def normalize_form_params(params) when is_map(params) do
    %{}
    |> maybe_put(@param_prefix <> "date_field", Map.get(params, "date_field"))
    |> maybe_put(@param_prefix <> "date_from", Map.get(params, "date_from"))
    |> maybe_put(@param_prefix <> "date_to", Map.get(params, "date_to"))
    |> maybe_put(@param_prefix <> "visibility", Map.get(params, "visibility"))
    |> maybe_put(@param_prefix <> "published", Map.get(params, "published"))
    |> maybe_put(@param_prefix <> "status", Map.get(params, "status"))
    |> maybe_put(@param_prefix <> "institution", Map.get(params, "institution"))
    |> maybe_put(@param_prefix <> "tags", encode_tag_ids(Map.get(params, "tag_ids")))
  end

  defp maybe_put(acc, _key, value) when value in [nil, ""], do: acc
  defp maybe_put(acc, key, value), do: Map.put(acc, key, value)

  defp encode_tag_ids(nil), do: nil
  defp encode_tag_ids([]), do: nil

  defp encode_tag_ids(ids) when is_list(ids) do
    ids
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(",")
  end

  defp encode_tag_ids(ids) when is_map(ids) do
    ids
    |> Map.values()
    |> encode_tag_ids()
  end

  defp encode_tag_ids(ids) when is_binary(ids), do: ids

  @spec parse(map(), Keyword.t()) :: t()
  def parse(params, _opts \\ []) when is_map(params) do
    date_field =
      params
      |> Map.get(@param_prefix <> "date_field")
      |> parse_atom(@date_field_default)

    date_from =
      params
      |> Map.get(@param_prefix <> "date_from")
      |> parse_date()

    date_to =
      params
      |> Map.get(@param_prefix <> "date_to")
      |> parse_date()

    visibility =
      params
      |> Map.get(@param_prefix <> "visibility")
      |> parse_atom(nil)

    published =
      params
      |> Map.get(@param_prefix <> "published")
      |> parse_boolean()

    status =
      params
      |> Map.get(@param_prefix <> "status")
      |> parse_atom(nil)

    institution_id =
      params
      |> Map.get(@param_prefix <> "institution")
      |> parse_integer()

    tags =
      params
      |> Map.get(@param_prefix <> "tags")
      |> parse_tag_ids()
      |> fetch_tags()

    %State{
      date_field: date_field,
      date_from: date_from,
      date_to: date_to,
      visibility: visibility,
      published: published,
      status: status,
      institution_id: institution_id,
      tags: tags
    }
  end

  defp parse_atom(nil, default), do: default
  defp parse_atom("", default), do: default

  defp parse_atom(value, default) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> default
      string -> String.to_existing_atom(string)
    end
  rescue
    ArgumentError -> default
  end

  defp parse_atom(value, _default) when is_atom(value), do: value

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_boolean(nil), do: nil
  defp parse_boolean(""), do: nil

  defp parse_boolean(value) when is_binary(value) do
    case String.downcase(value) do
      "true" -> true
      "false" -> false
      _ -> nil
    end
  end

  defp parse_boolean(value) when is_boolean(value), do: value

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_tag_ids(nil), do: []

  defp parse_tag_ids(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.flat_map(fn
      "" ->
        []

      str ->
        case Integer.parse(str) do
          {int, ""} -> [int]
          _ -> []
        end
    end)
  end

  defp parse_tag_ids(value) when is_list(value) do
    value
    |> Enum.flat_map(fn
      "" ->
        []

      nil ->
        []

      item when is_integer(item) ->
        [item]

      item when is_binary(item) ->
        case Integer.parse(item) do
          {int, ""} -> [int]
          _ -> []
        end
    end)
  end

  defp parse_tag_ids(value) when is_map(value) do
    value
    |> Map.values()
    |> parse_tag_ids()
  end

  @spec fetch_tags([integer()]) :: [tag_item()]
  def fetch_tags([]), do: []

  def fetch_tags(ids) do
    ids
    |> Tags.list_tags_by_ids()
    |> Enum.map(&%{id: &1.id, name: &1.name})
  end

  @spec add_tag(t(), tag_item()) :: t()
  def add_tag(%State{tags: tags} = state, %{id: id} = tag) when is_integer(id) do
    if Enum.any?(tags, &(&1.id == id)) do
      state
    else
      %{state | tags: tags ++ [tag]}
    end
  end

  @spec remove_tag(t(), integer()) :: t()
  def remove_tag(%State{tags: tags} = state, tag_id) when is_integer(tag_id) do
    %{state | tags: Enum.reject(tags, &(&1.id == tag_id))}
  end

  def remove_tag(state, _tag_id), do: state

  @spec active_count(t()) :: non_neg_integer()
  def active_count(%State{} = state) do
    [
      state.date_from != nil or state.date_to != nil,
      Enum.any?(state.tags),
      not is_nil(state.visibility),
      not is_nil(state.published),
      not is_nil(state.status),
      not is_nil(state.institution_id)
    ]
    |> Enum.count(& &1)
  end

  @spec tag_ids(t()) :: [integer()]
  def tag_ids(%State{tags: tags}) do
    Enum.map(tags, & &1.id)
  end

  @spec to_query_params(t(), Keyword.t()) :: map()
  def to_query_params(%State{} = state, opts \\ []) do
    as = Keyword.get(opts, :as, :strings)
    keys_fun = if(as == :atoms, do: &String.to_atom/1, else: & &1)

    %{}
    |> maybe_put_query(keys_fun.(@param_prefix <> "date_field"), encode_atom(state.date_field))
    |> maybe_put_query(keys_fun.(@param_prefix <> "date_from"), encode_date(state.date_from))
    |> maybe_put_query(keys_fun.(@param_prefix <> "date_to"), encode_date(state.date_to))
    |> maybe_put_query(keys_fun.(@param_prefix <> "visibility"), encode_atom(state.visibility))
    |> maybe_put_query(keys_fun.(@param_prefix <> "published"), encode_boolean(state.published))
    |> maybe_put_query(keys_fun.(@param_prefix <> "status"), encode_atom(state.status))
    |> maybe_put_query(
      keys_fun.(@param_prefix <> "institution"),
      encode_integer(state.institution_id)
    )
    |> maybe_put_query(
      keys_fun.(@param_prefix <> "tags"),
      encode_tag_ids(tag_ids(state))
    )
  end

  defp maybe_put_query(acc, _key, nil), do: acc
  defp maybe_put_query(acc, key, value), do: Map.put(acc, key, value)

  defp encode_atom(nil), do: nil
  defp encode_atom(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp encode_date(nil), do: nil
  defp encode_date(%Date{} = date), do: Date.to_iso8601(date)

  defp encode_boolean(nil), do: nil
  defp encode_boolean(value) when is_boolean(value), do: if(value, do: "true", else: "false")

  defp encode_integer(nil), do: nil
  defp encode_integer(int) when is_integer(int), do: Integer.to_string(int)

  @spec param_keys(:atoms | :strings) :: [atom() | String.t()]
  def param_keys(format \\ :strings) do
    keys = [
      @param_prefix <> "date_field",
      @param_prefix <> "date_from",
      @param_prefix <> "date_to",
      @param_prefix <> "visibility",
      @param_prefix <> "published",
      @param_prefix <> "status",
      @param_prefix <> "institution",
      @param_prefix <> "tags"
    ]

    case format do
      :atoms -> Enum.map(keys, &String.to_atom/1)
      _ -> keys
    end
  end

  @spec to_course_filters(t()) :: map()
  def to_course_filters(%State{} = state) do
    %{
      date_field: state.date_field,
      date_from: build_datetime(state.date_from, ~T[00:01:00]),
      date_to: build_datetime(state.date_to, ~T[23:59:00]),
      tag_ids: tag_ids(state),
      visibility: state.visibility,
      published: state.published,
      status: state.status,
      institution_id: state.institution_id
    }
  end

  defp build_datetime(nil, _time), do: nil

  defp build_datetime(%Date{} = date, %Time{} = time) do
    NaiveDateTime.new(date, time)
    |> case do
      {:ok, naive} -> naive
      _ -> nil
    end
  end
end
