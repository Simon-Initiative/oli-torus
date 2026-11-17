defmodule Oli.Interop.Audited do
  @moduledoc """
  Application boundary for audited API key commands. Each command records
  `credential_lifecycle_changed` in the same transaction as the change, with the lifecycle
  transition (`created`, `enabled`, `disabled`) and the scope flags that changed. The key value
  and its hash are never recorded; the administrator's hint (a label) goes in the details.
  Commands do not authorize the actor; callers keep their existing authorization.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Oli.Accounts.ProtectedKeys
  alias Oli.Auditing.{Command, Context}
  alias Oli.Auditing.EventCatalog.Fields
  alias Oli.Interop.ApiKey

  @settings ~w(payments_enabled products_enabled registration_enabled registration_namespace
    automation_setup_enabled)a

  @doc """
  Creates an API key for the plaintext `code` (stored only as its hash) with the label `hint`.
  The plaintext is returned to the caller by the caller itself, never by the event.
  """
  @spec create_key(Context.t(), String.t(), String.t()) :: {:ok, %ApiKey{}} | {:error, term()}
  def create_key(context, code, hint) when is_binary(code) do
    changeset =
      ApiKey.changeset(%ApiKey{}, %{
        hash: :crypto.hash(:md5, code) |> Base.encode16(),
        hint: hint
      })

    Command.run(:key, &Command.insert(&1, :key, context, changeset, spec()))
  end

  @doc "Enables or disables the API key with ID `id`."
  @spec set_key_status(Context.t(), pos_integer(), :enabled | :disabled) ::
          {:ok, %ApiKey{}} | {:error, term()}
  def set_key_status(context, id, status) when status in [:enabled, :disabled],
    do: update(context, id, &ApiKey.changeset(&1, %{status: status}))

  @doc """
  Updates the scope flags and registration namespace of the API key with ID `id`. Any other
  key field in `attrs` returns `{:error, :protected}` and writes nothing.
  """
  @spec update_key_settings(Context.t(), pos_integer(), map()) ::
          {:ok, %ApiKey{}} | {:error, term()}
  def update_key_settings(context, id, attrs) when is_map(attrs) do
    update(context, id, fn key ->
      changeset =
        key
        |> ApiKey.changeset(Map.take(attrs, Enum.flat_map(@settings, &[&1, Atom.to_string(&1)])))
        |> ProtectedKeys.validate(attrs, @settings)

      case ProtectedKeys.protected?(changeset) do
        true -> {:error, :protected}
        false -> changeset
      end
    end)
  end

  defp update(context, id, change) do
    Command.run(:key, &Command.update(&1, :key, context, {ApiKey, id}, change, spec()))
  end

  defp spec do
    %{
      event_type: :credential_lifecycle_changed,
      policy: Map.delete(Fields.credential(), :lifecycle),
      proposal: fn key, operation ->
        %{
          entity: {:api_key, key.id, %{id: key.id, label: key.hint}},
          event_key: "api_key:#{key.id}:#{operation}",
          details: %{"hint" => key.hint}
        }
      end,
      changes: fn key, operation, changes ->
        case {operation, changes} do
          {:created, _} ->
            Map.put(changes, "lifecycle", lifecycle("created"))

          {:updated, %{"status" => _}} ->
            Map.put(changes, "lifecycle", lifecycle(Atom.to_string(key.status)))

          {_operation, changes} ->
            changes
        end
      end
    }
  end

  defp lifecycle(transition), do: %{"operation" => "set", "after" => transition}
end
