defmodule Oli.MCP.Audited do
  @moduledoc """
  Application boundary for audited MCP bearer token commands. Each command records
  `credential_lifecycle_changed` with the lifecycle transition (`created`, `rotated`,
  `enabled`, `disabled`, `revoked`), the owning author as the affected person, and the
  project as scope. The token, its hash, and its hint (derived from the token) are never
  recorded; the plaintext is returned once to the caller.

  The existing check that the owner still collaborates on an active project runs inside the
  command's transaction. Other authorization stays with the callers.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export internal modules. Outgoing checks are off
  # because this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  alias Ecto.Multi
  alias Oli.Auditing.{Command, Context}
  alias Oli.MCP.Auth
  alias Oli.MCP.Auth.{BearerToken, TokenGenerator}

  @doc """
  Creates the token of `author_id` for `project_id` and returns `{:ok, {token, plaintext}}`.
  `hint` defaults to one derived from the token, as before.
  """
  @spec create_token(Context.t(), pos_integer(), pos_integer(), String.t() | nil) ::
          {:ok, {%BearerToken{}, String.t()}} | {:error, term()}
  def create_token(context, author_id, project_id, hint \\ nil) do
    plaintext = TokenGenerator.generate()

    attrs = %{
      author_id: author_id,
      project_id: project_id,
      hash: TokenGenerator.hash(plaintext),
      hint: hint || TokenGenerator.create_hint(plaintext)
    }

    Command.run(:token, fn multi ->
      multi
      |> access_check(author_id, project_id)
      |> Command.insert(
        {:token, :row},
        context,
        BearerToken.changeset(%BearerToken{}, attrs),
        spec(fn _token, :created -> "created" end)
      )
      |> Multi.run(:token, fn _repo, changes ->
        {:ok, {Map.fetch!(changes, {:token, :row}), plaintext}}
      end)
    end)
  end

  @doc """
  Replaces the token of `author_id` for `project_id` with a new one (`rotated`), or creates it
  when there is none. A disabled token returns `{:error, :token_disabled}`, as before.
  """
  @spec regenerate_token(Context.t(), pos_integer(), pos_integer(), String.t() | nil) ::
          {:ok, {%BearerToken{}, String.t()}} | {:error, term()}
  def regenerate_token(context, author_id, project_id, hint \\ nil) do
    case Auth.get_token_by_author_and_project(author_id, project_id) do
      nil ->
        create_token(context, author_id, project_id, hint)

      %BearerToken{status: :disabled} ->
        {:error, :token_disabled}

      %BearerToken{id: id} ->
        plaintext = TokenGenerator.generate()

        attrs = %{
          hash: TokenGenerator.hash(plaintext),
          hint: hint || TokenGenerator.create_hint(plaintext)
        }

        Command.run(:token, fn multi ->
          multi
          |> access_check(author_id, project_id)
          |> Command.update(
            {:token, :row},
            context,
            {BearerToken, id},
            &BearerToken.changeset(&1, attrs),
            spec(fn _token, :updated -> "rotated" end, always: true)
          )
          |> Multi.run(:token, fn _repo, changes ->
            {:ok, {Map.fetch!(changes, {:token, :row}), plaintext}}
          end)
        end)
    end
  end

  @doc "Enables (`:active`) or disables the token with ID `id`."
  @spec set_token_status(Context.t(), pos_integer(), :active | :disabled) ::
          {:ok, %BearerToken{}} | {:error, term()}
  def set_token_status(context, id, status) when status in [:active, :disabled] do
    Command.run(:token, fn multi ->
      Command.update(
        multi,
        :token,
        context,
        {BearerToken, id},
        &BearerToken.changeset(&1, %{status: status}),
        spec(fn
          %BearerToken{status: :active}, :updated -> "enabled"
          %BearerToken{status: :disabled}, :updated -> "disabled"
        end)
      )
    end)
  end

  @doc "Deletes the token with ID `id` and records its revocation."
  @spec revoke_token(Context.t(), pos_integer()) :: {:ok, %BearerToken{}} | {:error, term()}
  def revoke_token(context, id) do
    Command.run(:token, fn multi ->
      Command.delete(
        multi,
        :token,
        context,
        {BearerToken, id},
        spec(fn _token, :deleted -> "revoked" end)
      )
    end)
  end

  defp access_check(multi, author_id, project_id) do
    Multi.run(multi, {:token, :access}, fn _repo, _changes ->
      case Auth.verify_author_can_manage_token(author_id, project_id) do
        :ok -> {:ok, :ok}
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  # `transition` names the lifecycle change for the token and operation. With `always: true` an
  # update is recorded even when no audited field changed (a rotation only replaces the hash).
  defp spec(transition, opts \\ []) do
    %{
      event_type: :credential_lifecycle_changed,
      policy: %{status: :value},
      record_unchanged: Keyword.get(opts, :always, false),
      proposal: fn token, operation ->
        %{
          entity: {:mcp_token, token.id, %{id: token.id}},
          affected: {:author, token.author_id},
          scope: %{project_id: token.project_id},
          event_key: "mcp_token:#{token.id}:#{operation}"
        }
      end,
      changes: fn token, operation, changes ->
        changes
        |> Map.take(["status"])
        |> Map.put("lifecycle", %{"operation" => "set", "after" => transition.(token, operation)})
      end
    }
  end
end
