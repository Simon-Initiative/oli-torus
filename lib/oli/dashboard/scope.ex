defmodule Oli.Dashboard.Scope do
  @moduledoc """
  Canonical scope contract for dashboard data requests.

  Shared dashboard modules should consume this type as an immutable, normalized
  representation of course-level or container-level scope.
  """

  @enforce_keys [:container_type, :container_id]
  defstruct [:container_type, :container_id]

  @type container_type :: :course | :container

  @type t :: %__MODULE__{
          container_type: container_type(),
          container_id: pos_integer() | nil
        }

  @type input :: t() | map() | keyword()

  @type error :: {:invalid_scope, term()}

  @input_keys [:container_type, :container_id, :container]

  @spec new(input()) :: {:ok, t()} | {:error, error()}
  def new(%__MODULE__{} = scope) do
    {:ok, normalize(scope)}
  end

  def new(input) when is_map(input) or is_list(input) do
    with {:ok, attrs} <- normalize_input(input),
         {:ok, container_type, container_id} <- parse_container(attrs) do
      {:ok, normalize(%__MODULE__{container_type: container_type, container_id: container_id})}
    end
  end

  def new(input), do: {:error, {:invalid_scope, {:invalid_payload, input}}}

  @spec normalize(t()) :: t()
  def normalize(%__MODULE__{container_type: :course}) do
    %__MODULE__{container_type: :course, container_id: nil}
  end

  def normalize(%__MODULE__{container_type: :container, container_id: container_id}) do
    %__MODULE__{container_type: :container, container_id: container_id}
  end

  @spec container_key(t()) :: {:course, nil} | {:container, pos_integer()}
  def container_key(%__MODULE__{container_type: :course}), do: {:course, nil}

  def container_key(%__MODULE__{container_type: :container, container_id: container_id}),
    do: {:container, container_id}

  @spec course_scope?(t()) :: boolean()
  def course_scope?(%__MODULE__{container_type: :course}), do: true
  def course_scope?(%__MODULE__{}), do: false

  defp normalize_input(input) when is_list(input), do: normalize_input(Map.new(input))

  defp normalize_input(input) when is_map(input) do
    Enum.reduce(input, {:ok, %{}, []}, fn {raw_key, value}, {:ok, normalized, unknown} ->
      case normalize_key(raw_key) do
        {:ok, key} ->
          {:ok, Map.put(normalized, key, value), unknown}

        :error ->
          {:ok, normalized, [raw_key | unknown]}
      end
    end)
    |> case do
      {:ok, normalized, []} ->
        {:ok, normalized}

      {:ok, _normalized, unknown} ->
        {:error,
         {:invalid_scope, {:unknown_fields, unknown |> Enum.map(&inspect/1) |> Enum.sort()}}}
    end
  end

  defp normalize_key(key) when key in @input_keys, do: {:ok, key}
  defp normalize_key("container_type"), do: {:ok, :container_type}
  defp normalize_key("container_id"), do: {:ok, :container_id}
  defp normalize_key("container"), do: {:ok, :container}
  defp normalize_key(_), do: :error

  defp parse_container(attrs) do
    case Map.get(attrs, :container) do
      nil -> parse_container_type_and_id(attrs)
      container -> parse_container_selector(container)
    end
  end

  defp parse_container_type_and_id(attrs) do
    with {:ok, container_type} <- parse_container_type(Map.get(attrs, :container_type, :course)),
         {:ok, container_id} <- parse_container_id(Map.get(attrs, :container_id, nil)),
         :ok <- validate_type_and_id(container_type, container_id) do
      {:ok, container_type, container_id}
    end
  end

  defp parse_container_selector(:course), do: {:ok, :course, nil}
  defp parse_container_selector("course"), do: {:ok, :course, nil}

  defp parse_container_selector({:course, nil}), do: {:ok, :course, nil}

  defp parse_container_selector({:container, container_id}),
    do: parse_container_tuple(container_id)

  defp parse_container_selector(%{} = container_map) do
    with {:ok, attrs} <- normalize_container_map(container_map),
         {:ok, container_type} <- parse_container_type(Map.get(attrs, :type, :course)),
         {:ok, container_id} <- parse_container_id(Map.get(attrs, :id, nil)),
         :ok <- validate_type_and_id(container_type, container_id) do
      {:ok, container_type, container_id}
    end
  end

  defp parse_container_selector(other),
    do: {:error, {:invalid_scope, {:invalid_container, other}}}

  defp parse_container_tuple(container_id) do
    with {:ok, normalized_id} <- parse_container_id(container_id),
         :ok <- validate_type_and_id(:container, normalized_id) do
      {:ok, :container, normalized_id}
    end
  end

  defp normalize_container_map(map) do
    Enum.reduce(map, {:ok, %{}, []}, fn {raw_key, value}, {:ok, normalized, unknown} ->
      case normalize_container_map_key(raw_key) do
        {:ok, key} -> {:ok, Map.put(normalized, key, value), unknown}
        :error -> {:ok, normalized, [raw_key | unknown]}
      end
    end)
    |> case do
      {:ok, normalized, []} ->
        {:ok, normalized}

      {:ok, _normalized, unknown} ->
        {:error,
         {:invalid_scope,
          {:unknown_container_fields, unknown |> Enum.map(&inspect/1) |> Enum.sort()}}}
    end
  end

  defp normalize_container_map_key(key) when key in [:type, :id], do: {:ok, key}
  defp normalize_container_map_key("type"), do: {:ok, :type}
  defp normalize_container_map_key("id"), do: {:ok, :id}
  defp normalize_container_map_key(_), do: :error

  defp parse_container_type(nil), do: {:ok, :course}
  defp parse_container_type(:course), do: {:ok, :course}
  defp parse_container_type(:container), do: {:ok, :container}
  defp parse_container_type("course"), do: {:ok, :course}
  defp parse_container_type("container"), do: {:ok, :container}

  defp parse_container_type(other) do
    {:error, {:invalid_scope, {:unsupported_container_type, other}}}
  end

  defp parse_container_id(nil), do: {:ok, nil}

  defp parse_container_id(container_id) when is_integer(container_id) and container_id > 0,
    do: {:ok, container_id}

  defp parse_container_id(container_id) when is_binary(container_id) do
    case Integer.parse(container_id) do
      {value, ""} when value > 0 -> {:ok, value}
      _ -> {:error, {:invalid_scope, {:invalid_container_id, container_id}}}
    end
  end

  defp parse_container_id(other), do: {:error, {:invalid_scope, {:invalid_container_id, other}}}

  defp validate_type_and_id(:course, nil), do: :ok

  defp validate_type_and_id(:course, container_id) do
    {:error, {:invalid_scope, {:course_scope_disallows_container_id, container_id}}}
  end

  defp validate_type_and_id(:container, nil) do
    {:error, {:invalid_scope, {:missing_container_id, :container}}}
  end

  defp validate_type_and_id(:container, container_id)
       when is_integer(container_id) and container_id > 0,
       do: :ok
end
