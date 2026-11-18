defmodule Oli.Utils.JSONValidation do
  @moduledoc """
  Library-independent JSON Schema construction and validation.

  Built schemas are opaque handles. Identical decoded schemas share a built
  validator for the lifetime of the VM; validation never changes submitted data.
  """

  defstruct [:validator]

  @opaque t :: %__MODULE__{validator: term()}
  @type error :: {String.t(), String.t()}

  defmodule Resolver do
    @moduledoc false
    @behaviour JSV.Resolver

    @impl true
    def resolve(uri, _options) do
      try do
        {:ok, Oli.Utils.SchemaResolver.resolve_uri(uri)}
      rescue
        error -> {:error, error}
      catch
        reason -> {:error, reason}
      end
    end
  end

  @doc """
  Builds or reuses a validator for a decoded JSON schema, raising on invalid schemas.

  Schema documents must be trusted application configuration. Builds are serialized
  per schema so concurrent callers reuse the same cached validator. The optional
  `:cache_revision` token must change when externally referenced schemas change.
  """
  @spec build!(map() | boolean(), keyword()) :: t()
  def build!(schema, opts \\ []) do
    key = {__MODULE__, Keyword.get(opts, :cache_revision), schema}

    case :persistent_term.get(key, nil) do
      nil ->
        :global.trans(
          {key, self()},
          fn ->
            case :persistent_term.get(key, nil) do
              nil ->
                root = %__MODULE__{
                  validator: JSV.build!(schema, resolver: Resolver, formats: true, atoms: false)
                }

                :persistent_term.put(key, root)
                root

              root ->
                root
            end
          end,
          [node()]
        )

      root ->
        root
    end
  end

  @doc """
  Validates data against a built schema, returning messages and JSON Pointer paths.
  """
  @spec validate(t(), term()) :: :ok | {:error, [error()]}
  def validate(%__MODULE__{validator: validator}, data) do
    case JSV.validate(data, validator, cast: false, cast_formats: false) do
      {:ok, _data} ->
        :ok

      {:error, error} ->
        {:error,
         error
         |> JSV.normalize_error(keys: :strings, min_error_level: JSV.ErrorFormatter.level_cause())
         |> flatten_errors()}
    end
  end

  defp flatten_errors(%{"details" => details}) do
    Enum.flat_map(details, &flatten_errors/1)
  end

  defp flatten_errors(unit) do
    path = unit["instanceLocation"] || "#"

    Enum.flat_map(unit["errors"] || [], fn error ->
      case error["details"] do
        details when is_list(details) and details != [] ->
          case Enum.flat_map(details, &flatten_errors/1) do
            [] -> [{error["message"], path}]
            errors -> errors
          end

        _ ->
          [{error["message"], path}]
      end
    end)
  end
end
