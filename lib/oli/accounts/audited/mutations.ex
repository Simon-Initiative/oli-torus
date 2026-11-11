defmodule Oli.Accounts.Audited.Mutations do
  @moduledoc false

  # Raw account writes for `Oli.Accounts.Audited`. They perform no authorization, auditing, or
  # transaction handling; only the audited coordinator may call them.

  import Ecto.Query, only: [from: 2]

  alias Oli.Accounts.{Author, AuthorToken, User, UserToken}
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

  @spec insert_account(Ecto.Changeset.t()) ::
          {:ok, %User{} | %Author{}} | {:error, Ecto.Changeset.t()}
  def insert_account(%Ecto.Changeset{data: %schema{}} = changeset) when schema in [User, Author],
    do: Repo.insert(changeset)

  @spec invited_user_row(String.t()) :: map()
  def invited_user_row(email) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    %{changes: changes} = User.invite_changeset(%User{}, %{email: email})
    Enum.into(changes, %{inserted_at: now, updated_at: now})
  end

  # One statement for every row, as invitation forms and bulk Scenario setup submit them together.
  @spec insert_user_rows([map()]) :: {:ok, {non_neg_integer(), [%User{}]}}
  def insert_user_rows(rows), do: {:ok, Repo.insert_all(User, rows, returning: true)}

  # Deletes every token of the account and returns how many were session tokens.
  @spec delete_all_tokens(:user | :author, %User{} | %Author{}) :: {:ok, non_neg_integer()}
  def delete_all_tokens(kind, %{id: id}) do
    {:ok, sessions} = delete_tokens(kind, id, ["session"])
    {_count, _} = Repo.delete_all(tokens(kind, id))
    {:ok, sessions}
  end

  @spec delete_tokens(:user | :author, pos_integer(), [String.t()]) :: {:ok, non_neg_integer()}
  def delete_tokens(kind, id, contexts) do
    {count, _} = Repo.delete_all(from(t in tokens(kind, id), where: t.context in ^contexts))
    {:ok, count}
  end

  # Inserts a one-time email token and returns its encoded value.
  @spec insert_email_token(:user | :author, %User{} | %Author{}, String.t()) ::
          {:ok, String.t()} | {:error, Ecto.Changeset.t()}
  def insert_email_token(:user, %User{} = user, context) do
    {encoded, token} = UserToken.build_email_token(user, context)
    with {:ok, _token} <- Repo.insert(token), do: {:ok, encoded}
  end

  def insert_email_token(:author, %Author{} = author, context) do
    {encoded, token} = AuthorToken.build_email_token(author, context)
    with {:ok, _token} <- Repo.insert(token), do: {:ok, encoded}
  end

  defp tokens(:user, id), do: from(t in UserToken, where: t.user_id == ^id)
  defp tokens(:author, id), do: from(t in AuthorToken, where: t.author_id == ^id)

  # Inserts a login-provider identity; only the provider and its account uid are taken.
  @spec insert_identity(%User{} | %Author{}, map()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def insert_identity(%User{} = user, params) do
    user
    |> Ecto.build_assoc(:user_identities)
    |> Oli.AssentAuth.UserIdentity.changeset(Map.take(params, ["uid", "provider"]))
    |> Repo.insert()
  end

  def insert_identity(%Author{} = author, params) do
    author
    |> Ecto.build_assoc(:user_identities)
    |> Oli.AssentAuth.AuthorIdentity.changeset(Map.take(params, ["uid", "provider"]))
    |> Repo.insert()
  end

  @spec delete_identities(:user | :author, pos_integer(), [pos_integer()]) ::
          {:ok, {non_neg_integer(), nil}}
  def delete_identities(:user, user_id, ids) do
    {:ok,
     Repo.delete_all(
       from(i in Oli.AssentAuth.UserIdentity, where: i.user_id == ^user_id and i.id in ^ids)
     )}
  end

  def delete_identities(:author, author_id, ids) do
    {:ok,
     Repo.delete_all(
       from(i in Oli.AssentAuth.AuthorIdentity,
         where: i.user_id == ^author_id and i.id in ^ids
       )
     )}
  end

  # `roles` are platform role rows that already exist; `put_assoc` only rewrites the join rows.
  @spec put_platform_roles(%User{}, [struct()]) :: {:ok, %User{}} | {:error, Ecto.Changeset.t()}
  def put_platform_roles(%User{} = user, roles) do
    user
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:platform_roles, roles)
    |> Repo.update()
  end
end
