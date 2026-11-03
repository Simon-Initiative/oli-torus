defmodule Oli.Accounts.Audited.Mutations do
  @moduledoc false

  # Raw account writes for `Oli.Accounts.Audited`. They perform no authorization, auditing, or
  # transaction handling; only the audited coordinator may call them.

  alias Oli.Accounts.User
  alias Oli.Repo

  # A row that still references the user through a restrictive foreign key blocks the deletion.
  # The database has already aborted the surrounding transaction, so the caller must roll back.
  @spec delete_user(%User{}) :: {:ok, %User{}} | {:error, Ecto.Changeset.t() | :referenced}
  def delete_user(%User{} = user) do
    Repo.delete(user)
  rescue
    error in Ecto.ConstraintError ->
      case error.type do
        :foreign_key -> {:error, :referenced}
        _ -> reraise error, __STACKTRACE__
      end
  end
end
