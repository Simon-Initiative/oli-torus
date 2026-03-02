defmodule Oli.Dashboard.OracleContext do
  @moduledoc """
  Immutable execution context for dashboard oracle requests.

  This shared contract intentionally allows only a constrained field set so
  oracle modules remain datastore-agnostic and authorization-scoped.
  """

  alias Oli.Dashboard.Scope

  @enforce_keys [:dashboard_context_type, :dashboard_context_id, :user_id, :scope]
  defstruct [:dashboard_context_type, :dashboard_context_id, :user_id, :scope, :request_id]

  @type dashboard_context_type :: :section | :project

  @type t :: %__MODULE__{
          dashboard_context_type: dashboard_context_type(),
          dashboard_context_id: pos_integer(),
          user_id: pos_integer(),
          scope: Scope.t(),
          request_id: String.t() | nil
        }

  @type input :: keyword() | map() | t()
  @type error :: {:invalid_oracle_context, term()}

  @allowed_keys [
    :dashboard_context_type,
    :dashboard_context_id,
    :user_id,
    :scope,
    :request_id,
    :context_type,
    :context_id
  ]

  @spec new(input()) :: {:ok, t()} | {:error, error()}
  def new(%__MODULE__{} = context), do: {:ok, context}

  def new(input) when is_list(input), do: new(Map.new(input))

  def new(input) when is_map(input) do
    with {:ok, attrs} <- normalize_attrs(input),
         {:ok, dashboard_context_type} <-
           normalize_context_type(Map.get(attrs, :dashboard_context_type)),
         {:ok, dashboard_context_id} <-
           normalize_positive_integer(
             Map.get(attrs, :dashboard_context_id),
             :dashboard_context_id
           ),
         {:ok, user_id} <- normalize_positive_integer(Map.get(attrs, :user_id), :user_id),
         {:ok, scope} <- normalize_scope(Map.get(attrs, :scope, %{})),
         {:ok, request_id} <- normalize_request_id(Map.get(attrs, :request_id, nil)) do
      {:ok,
       %__MODULE__{
         dashboard_context_type: dashboard_context_type,
         dashboard_context_id: dashboard_context_id,
         user_id: user_id,
         scope: scope,
         request_id: request_id
       }}
    end
  end

  def new(other), do: {:error, {:invalid_oracle_context, {:invalid_payload, other}}}

  @spec with_scope(t(), Scope.input()) :: t()
  def with_scope(%__MODULE__{} = context, scope_input) do
    case Scope.new(scope_input) do
      {:ok, scope} ->
        %{context | scope: scope}

      {:error, reason} ->
        raise ArgumentError, "invalid scope for OracleContext.with_scope/2: #{inspect(reason)}"
    end
  end

  @spec to_metadata(t()) :: map()
  def to_metadata(%__MODULE__{} = context) do
    metadata = %{
      dashboard_context_type: context.dashboard_context_type,
      dashboard_context_id: context.dashboard_context_id,
      user_id: context.user_id,
      scope: Scope.container_key(context.scope)
    }

    case context.request_id do
      nil -> metadata
      request_id -> Map.put(metadata, :request_id, request_id)
    end
  end

  defp normalize_attrs(attrs) do
    Enum.reduce(attrs, {:ok, %{}, []}, fn {raw_key, value}, {:ok, normalized, unknown} ->
      case normalize_key(raw_key) do
        {:ok, key} -> {:ok, Map.put(normalized, key, value), unknown}
        :error -> {:ok, normalized, [raw_key | unknown]}
      end
    end)
    |> case do
      {:ok, normalized, []} ->
        normalized = normalize_aliases(normalized)
        {:ok, normalized}

      {:ok, _normalized, unknown} ->
        {:error,
         {:invalid_oracle_context,
          {:unknown_fields, unknown |> Enum.map(&inspect/1) |> Enum.sort()}}}
    end
  end

  defp normalize_aliases(attrs) do
    attrs
    |> maybe_put(:dashboard_context_type, :context_type)
    |> maybe_put(:dashboard_context_id, :context_id)
  end

  defp maybe_put(attrs, target_key, source_key) do
    case {Map.get(attrs, target_key), Map.get(attrs, source_key)} do
      {nil, source_value} when not is_nil(source_value) ->
        Map.put(attrs, target_key, source_value)

      _ ->
        attrs
    end
  end

  defp normalize_key(key) when key in @allowed_keys, do: {:ok, key}
  defp normalize_key("dashboard_context_type"), do: {:ok, :dashboard_context_type}
  defp normalize_key("dashboard_context_id"), do: {:ok, :dashboard_context_id}
  defp normalize_key("user_id"), do: {:ok, :user_id}
  defp normalize_key("scope"), do: {:ok, :scope}
  defp normalize_key("request_id"), do: {:ok, :request_id}
  defp normalize_key("context_type"), do: {:ok, :context_type}
  defp normalize_key("context_id"), do: {:ok, :context_id}
  defp normalize_key(_), do: :error

  defp normalize_scope(scope_input), do: Scope.new(scope_input)

  defp normalize_context_type(:section), do: {:ok, :section}
  defp normalize_context_type(:project), do: {:ok, :project}
  defp normalize_context_type("section"), do: {:ok, :section}
  defp normalize_context_type("project"), do: {:ok, :project}

  defp normalize_context_type(other) do
    {:error, {:invalid_oracle_context, {:unsupported_dashboard_context_type, other}}}
  end

  defp normalize_positive_integer(value, _field) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_positive_integer(value, field) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} when parsed > 0 -> {:ok, parsed}
      _ -> {:error, {:invalid_oracle_context, {:invalid_positive_integer, field, value}}}
    end
  end

  defp normalize_positive_integer(value, field) do
    {:error, {:invalid_oracle_context, {:invalid_positive_integer, field, value}}}
  end

  defp normalize_request_id(nil), do: {:ok, nil}
  defp normalize_request_id(request_id) when is_binary(request_id), do: {:ok, request_id}

  defp normalize_request_id(other) do
    {:error, {:invalid_oracle_context, {:invalid_request_id, other}}}
  end
end
