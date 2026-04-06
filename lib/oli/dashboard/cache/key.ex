defmodule Oli.Dashboard.Cache.Key do
  @moduledoc """
  Canonical dashboard cache key construction and parsing.
  """

  alias Oli.Dashboard.OracleContext
  alias Oli.Dashboard.Scope

  @typedoc "Canonical cache oracle identifier."
  @type oracle_key :: atom() | String.t()

  @typedoc "Version metadata used by deterministic cache keys."
  @type version :: non_neg_integer() | String.t()

  @typedoc "In-process cache key shape."
  @type inprocess_key ::
          {:dashboard_oracle, oracle_key(), pos_integer(), Scope.container_type(),
           pos_integer() | nil, version(), version()}

  @typedoc "Revisit cache key shape."
  @type revisit_key ::
          {:dashboard_revisit_oracle, pos_integer(), pos_integer(), Scope.container_type(),
           pos_integer() | nil, oracle_key(), version(), version()}

  @typedoc "All supported cache key tuple shapes."
  @type cache_key :: inprocess_key() | revisit_key()

  @typedoc "Metadata required to build canonical keys."
  @type key_meta :: %{
          required(:oracle_version) => version(),
          required(:data_version) => version()
        }

  @typedoc "Identity map derived from keys for deterministic matching."
  @type identity :: %{
          required(:key_type) => :inprocess | :revisit,
          required(:dashboard_context_id) => pos_integer(),
          required(:container_type) => Scope.container_type(),
          required(:container_id) => pos_integer() | nil,
          required(:oracle_key) => oracle_key(),
          required(:oracle_version) => version(),
          required(:data_version) => version(),
          optional(:user_id) => pos_integer()
        }

  @typedoc "Cache key error."
  @type error :: {:invalid_cache_key, term()}

  @doc """
  Builds a canonical in-process cache key from context, container scope, oracle key, and versions.
  """
  @spec inprocess(OracleContext.input(), Scope.input(), oracle_key(), key_meta() | keyword()) ::
          {:ok, inprocess_key()} | {:error, error()}
  def inprocess(context_input, scope_input, oracle_key, meta) do
    with {:ok, context_id} <- normalize_context_id(context_input),
         {:ok, {container_type, container_id}} <- normalize_container(scope_input),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(oracle_key),
         {:ok, metadata} <- normalize_meta(meta),
         {:ok, oracle_version} <- fetch_version(metadata, :oracle_version),
         {:ok, data_version} <- fetch_version(metadata, :data_version) do
      {:ok,
       {:dashboard_oracle, normalized_oracle_key, context_id, container_type, container_id,
        oracle_version, data_version}}
    end
  end

  @doc """
  Builds a canonical revisit cache key from user/context/container/oracle/version identity.
  """
  @spec revisit(
          pos_integer(),
          OracleContext.input(),
          Scope.input(),
          oracle_key(),
          key_meta() | keyword()
        ) ::
          {:ok, revisit_key()} | {:error, error()}
  def revisit(user_id, context_input, scope_input, oracle_key, meta) do
    with {:ok, normalized_user_id} <- normalize_positive_integer(user_id, :user_id),
         {:ok, context_id} <- normalize_context_id(context_input),
         {:ok, {container_type, container_id}} <- normalize_container(scope_input),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(oracle_key),
         {:ok, metadata} <- normalize_meta(meta),
         {:ok, oracle_version} <- fetch_version(metadata, :oracle_version),
         {:ok, data_version} <- fetch_version(metadata, :data_version) do
      {:ok,
       {:dashboard_revisit_oracle, normalized_user_id, context_id, container_type, container_id,
        normalized_oracle_key, oracle_version, data_version}}
    end
  end

  @doc """
  Parses canonical in-process or revisit cache tuples into structured identity metadata.
  """
  @spec parse(cache_key()) :: {:ok, identity()} | {:error, error()}
  def parse(
        {:dashboard_oracle, oracle_key, context_id, container_type, container_id, oracle_version,
         data_version}
      ) do
    with {:ok, normalized_context_id} <-
           normalize_positive_integer(context_id, :dashboard_context_id),
         {:ok, {normalized_container_type, normalized_container_id}} <-
           normalize_container(%{container_type: container_type, container_id: container_id}),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(oracle_key),
         {:ok, normalized_oracle_version} <- normalize_version(oracle_version, :oracle_version),
         {:ok, normalized_data_version} <- normalize_version(data_version, :data_version) do
      {:ok,
       %{
         key_type: :inprocess,
         dashboard_context_id: normalized_context_id,
         container_type: normalized_container_type,
         container_id: normalized_container_id,
         oracle_key: normalized_oracle_key,
         oracle_version: normalized_oracle_version,
         data_version: normalized_data_version
       }}
    end
  end

  def parse(
        {:dashboard_revisit_oracle, user_id, context_id, container_type, container_id, oracle_key,
         oracle_version, data_version}
      ) do
    with {:ok, normalized_user_id} <- normalize_positive_integer(user_id, :user_id),
         {:ok, normalized_context_id} <-
           normalize_positive_integer(context_id, :dashboard_context_id),
         {:ok, {normalized_container_type, normalized_container_id}} <-
           normalize_container(%{container_type: container_type, container_id: container_id}),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(oracle_key),
         {:ok, normalized_oracle_version} <- normalize_version(oracle_version, :oracle_version),
         {:ok, normalized_data_version} <- normalize_version(data_version, :data_version) do
      {:ok,
       %{
         key_type: :revisit,
         user_id: normalized_user_id,
         dashboard_context_id: normalized_context_id,
         container_type: normalized_container_type,
         container_id: normalized_container_id,
         oracle_key: normalized_oracle_key,
         oracle_version: normalized_oracle_version,
         data_version: normalized_data_version
       }}
    end
  end

  def parse(other), do: {:error, {:invalid_cache_key, {:unsupported_key_shape, other}}}

  @doc """
  Verifies whether an existing key matches an expected identity map.
  """
  @spec matches_identity?(cache_key(), map()) :: boolean()
  def matches_identity?(cache_key, identity) when is_map(identity) do
    case {parse(cache_key), normalize_expected_identity(identity)} do
      {{:ok, parsed}, {:ok, expected}} -> identity_match?(parsed, expected)
      _ -> false
    end
  end

  def matches_identity?(_cache_key, _identity), do: false

  defp normalize_context_id(%OracleContext{dashboard_context_id: context_id}) do
    normalize_positive_integer(context_id, :dashboard_context_id)
  end

  defp normalize_context_id(%{} = context_map) do
    case Map.fetch(context_map, :dashboard_context_id) do
      {:ok, context_id} ->
        normalize_positive_integer(context_id, :dashboard_context_id)

      :error ->
        {:error, {:invalid_cache_key, {:missing_context_id, context_map}}}
    end
  end

  defp normalize_context_id(other), do: {:error, {:invalid_cache_key, {:invalid_context, other}}}

  defp normalize_container(scope_input) do
    case Scope.new(scope_input) do
      {:ok, %Scope{container_type: container_type, container_id: container_id}} ->
        {:ok, {container_type, container_id}}

      {:error, reason} ->
        {:error, {:invalid_cache_key, {:invalid_container, reason}}}
    end
  end

  defp normalize_meta(meta) when is_list(meta), do: normalize_meta(Map.new(meta))

  defp normalize_meta(meta) when is_map(meta) do
    atomized =
      Enum.reduce(meta, %{}, fn
        {key, value}, acc when is_atom(key) ->
          Map.put(acc, key, value)

        {"oracle_version", value}, acc ->
          Map.put(acc, :oracle_version, value)

        {"data_version", value}, acc ->
          Map.put(acc, :data_version, value)

        {_unknown_key, _value}, acc ->
          acc
      end)

    {:ok, atomized}
  end

  defp normalize_meta(other), do: {:error, {:invalid_cache_key, {:invalid_meta, other}}}

  defp fetch_version(meta, field) do
    case Map.fetch(meta, field) do
      {:ok, version} ->
        normalize_version(version, field)

      :error ->
        {:error, {:invalid_cache_key, {:missing_version, field}}}
    end
  end

  defp normalize_expected_identity(identity) do
    key_type = Map.get(identity, :key_type, :inprocess)

    with {:ok, normalized_key_type} <- normalize_key_type(key_type),
         {:ok, normalized_context_id} <-
           normalize_positive_integer(
             Map.get(identity, :dashboard_context_id),
             :dashboard_context_id
           ),
         {:ok, {container_type, container_id}} <-
           normalize_container(%{
             container_type: Map.get(identity, :container_type),
             container_id: Map.get(identity, :container_id)
           }),
         {:ok, normalized_oracle_key} <- normalize_oracle_key(Map.get(identity, :oracle_key)),
         {:ok, normalized_oracle_version} <-
           normalize_version(Map.get(identity, :oracle_version), :oracle_version),
         {:ok, normalized_data_version} <-
           normalize_version(Map.get(identity, :data_version), :data_version),
         {:ok, normalized_user_id} <- normalize_optional_user_id(normalized_key_type, identity) do
      normalized =
        %{
          key_type: normalized_key_type,
          dashboard_context_id: normalized_context_id,
          container_type: container_type,
          container_id: container_id,
          oracle_key: normalized_oracle_key,
          oracle_version: normalized_oracle_version,
          data_version: normalized_data_version
        }
        |> maybe_put_user_id(normalized_user_id)

      {:ok, normalized}
    end
  end

  defp normalize_key_type(:inprocess), do: {:ok, :inprocess}
  defp normalize_key_type(:revisit), do: {:ok, :revisit}
  defp normalize_key_type(other), do: {:error, {:invalid_cache_key, {:invalid_key_type, other}}}

  defp normalize_optional_user_id(:inprocess, _identity), do: {:ok, nil}

  defp normalize_optional_user_id(:revisit, identity) do
    normalize_positive_integer(Map.get(identity, :user_id), :user_id)
  end

  defp normalize_oracle_key(value) when is_atom(value), do: {:ok, value}

  defp normalize_oracle_key(value) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_oracle_key(value),
    do: {:error, {:invalid_cache_key, {:invalid_oracle_key, value}}}

  defp normalize_version(value, _field) when is_integer(value) and value >= 0, do: {:ok, value}

  defp normalize_version(value, _field) when is_binary(value) and byte_size(value) > 0,
    do: {:ok, value}

  defp normalize_version(value, field),
    do: {:error, {:invalid_cache_key, {:invalid_version, field, value}}}

  defp normalize_positive_integer(value, _field) when is_integer(value) and value > 0,
    do: {:ok, value}

  defp normalize_positive_integer(value, field),
    do: {:error, {:invalid_cache_key, {:invalid_positive_integer, field, value}}}

  defp maybe_put_user_id(identity, nil), do: identity
  defp maybe_put_user_id(identity, user_id), do: Map.put(identity, :user_id, user_id)

  defp identity_match?(%{key_type: :inprocess} = parsed, %{key_type: :inprocess} = expected) do
    parsed.dashboard_context_id == expected.dashboard_context_id and
      parsed.container_type == expected.container_type and
      parsed.container_id == expected.container_id and
      parsed.oracle_key == expected.oracle_key and
      parsed.oracle_version == expected.oracle_version and
      parsed.data_version == expected.data_version
  end

  defp identity_match?(%{key_type: :revisit} = parsed, %{key_type: :revisit} = expected) do
    parsed.user_id == expected.user_id and
      parsed.dashboard_context_id == expected.dashboard_context_id and
      parsed.container_type == expected.container_type and
      parsed.container_id == expected.container_id and
      parsed.oracle_key == expected.oracle_key and
      parsed.oracle_version == expected.oracle_version and
      parsed.data_version == expected.data_version
  end

  defp identity_match?(_parsed, _expected), do: false
end
