defmodule Oli.Accounts.Audited.Mutations do
  @moduledoc false

  # Raw account writes for `Oli.Accounts.Audited`. They perform no authorization, auditing, or
  # transaction handling; only the audited coordinator may call them.

  alias Oli.Accounts.{Author, User}
  alias Oli.Repo

  # A row that still references the account through a restrictive foreign key blocks the
  # deletion. Postgres has already marked the transaction as failed, so the caller must return
  # an error and let it roll back; no further queries can run in it.
  @spec delete_account(%User{} | %Author{}) ::
          {:ok, %User{} | %Author{}} | {:error, Ecto.Changeset.t() | :referenced}
  def delete_account(%schema{} = account) when schema in [User, Author] do
    Repo.delete(account)
  rescue
    error in Ecto.ConstraintError ->
      case error.type do
        :foreign_key -> {:error, :referenced}
        _ -> reraise error, __STACKTRACE__
      end
  end

  @spec update_account(Ecto.Changeset.t()) ::
          {:ok, %User{} | %Author{}} | {:error, Ecto.Changeset.t()}
  def update_account(%Ecto.Changeset{data: %schema{}} = changeset) when schema in [User, Author],
    do: Repo.update(changeset)

  # `roles` are platform role rows that already exist; `put_assoc` only rewrites the join rows.
  @spec put_platform_roles(%User{}, [struct()]) :: {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def put_platform_roles(%User{} = user, roles) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:platform_roles, roles)
    |> Repo.update()
  end
end
