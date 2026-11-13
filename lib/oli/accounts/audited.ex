defmodule Oli.Accounts.Audited do
  @moduledoc """
  Application boundary for audited account commands.

  Each command performs the account write and records its audit event in one transaction, so
  the change and its event are committed or rolled back together. Commands do not authorize the
  actor: callers keep their existing authorization, such as the route's administrator plug. The
  internal mutation module is not exported to callers.
  """

  # This configuration is what makes CI fail when a caller bypasses this facade.
  # Keep the boundary top-level and never export Mutations. Outgoing checks are off because
  # this boundary calls into Oli, which depends on it; incoming checks stay on.
  use Boundary, top_level?: true, exports: [], check: [out: false]

  import Ecto.Query, warn: false

  require Logger

  alias Ecto.Multi
  alias Oli.Accounts.User
  alias Oli.Accounts.Audited.Mutations
  alias Oli.Auditing
  alias Oli.Auditing.Context
  alias Oli.Repo

  @type delete_result :: %{user_id: pos_integer()}

  @type delete_error ::
          :invalid_request
          | :not_found
          | :delete_failed
          | :nested_transaction
          | Auditing.Error.t()

  @doc """
  Deletes the user with ID `user_id` and records `user_deleted` in the same transaction.

  `context` identifies the author who performs the deletion and becomes the event's actor; it
  must belong to an author. This function does not check the author's permissions: the caller
  must already have authorized them, as the user-detail route does for account administrators.

  The user is locked before deletion, so concurrent deletions of the same user commit one
  deletion and one event, and the others return `:not_found`.

  Returns `{:error, :nested_transaction}` when called inside another transaction; compose
  `delete_user_multi/4` instead. Any error rolls back both the deletion and the event.
  """
  @spec delete_user(Context.t(), pos_integer()) ::
          {:ok, delete_result()} | {:error, delete_error()}
  def delete_user(context, user_id) do
    case Repo.in_transaction?() do
      true ->
        {:error, :nested_transaction}

      false ->
        Multi.new()
        |> delete_user_multi(:delete_user, context, user_id)
        |> Repo.transaction()
        |> case do
          {:ok, %{delete_user: result}} -> {:ok, result}
          {:error, _step, reason, _changes} -> {:error, reason}
        end
    end
  end

  @doc """
  Adds the steps of `delete_user/2` to `multi`, for callers that own the transaction.

  The result is stored under `name`; internal steps use `{name, step}` names. The caller's
  transaction decides whether the deletion and its event commit.
  """
  @spec delete_user_multi(Multi.t(), Multi.name(), Context.t(), pos_integer()) :: Multi.t()
  def delete_user_multi(
        %Multi{} = multi,
        name,
        %Context{actor_type: :author, author_id: author_id} = context,
        user_id
      )
      when is_integer(author_id) and is_integer(user_id) and user_id > 0 do
    multi
    |> Multi.run({name, :user}, fn repo, _changes -> lock_user(repo, user_id) end)
    |> Multi.run({name, :deleted}, fn _repo, changes ->
      changes |> Map.fetch!({name, :user}) |> delete()
    end)
    |> Auditing.append({name, :event}, fn changes ->
      user_deleted_event(context, Map.fetch!(changes, {name, :deleted}))
    end)
    |> Multi.run(name, fn _repo, changes ->
      {:ok, %{user_id: Map.fetch!(changes, {name, :deleted}).id}}
    end)
  end

  def delete_user_multi(%Multi{} = multi, name, _context, _user_id),
    do: Multi.error(multi, name, :invalid_request)

  defp lock_user(repo, user_id) do
    case repo.one(from(u in User, where: u.id == ^user_id, lock: "FOR UPDATE")) do
      %User{} = user -> {:ok, user}
      nil -> {:error, :not_found}
    end
  end

  defp delete(user) do
    case Mutations.delete_user(user) do
      {:ok, user} ->
        {:ok, user}

      {:error, reason} ->
        Logger.warning(
          "Audited user deletion failed user_id=#{user.id} reason=#{failure_reason(reason)}"
        )

        {:error, :delete_failed}
    end
  end

  # Logs only error keys, never changeset values, so the user's personal data stays out of logs.
  defp failure_reason(:referenced), do: "referenced"

  defp failure_reason(%Ecto.Changeset{errors: errors}),
    do: "changeset:" <> (errors |> Keyword.keys() |> Enum.uniq() |> Enum.join(","))

  defp user_deleted_event(context, user) do
    Auditing.build(context, %{
      event_type: :user_deleted,
      entity: {:user, user.id, user},
      affected: {:user, user.id},
      event_key: "account:primary:deleted",
      details: %{
        "email" => user.email,
        "name" => user.name,
        "deleted_by" => context.actor_snapshot["email"]
      }
    })
  end
end
