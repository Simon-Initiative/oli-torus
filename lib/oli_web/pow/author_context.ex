defmodule OliWeb.Pow.AuthorContext do
  @moduledoc """
  Custom module that handles pow users context for author.
  """

  use Pow.Ecto.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.Author

  alias Oli.{Repo, Utils}
  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias OliWeb.Router.Helpers, as: Routes

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def lock(user) do
    user
    |> Author.lock_changeset()
    |> Repo.update()
    |> maybe_delete_author_cached()
  end

  @spec unlock(map()) :: {:ok, map()} | {:error, map()}
  def unlock(user) do
    user
    |> Author.noauth_changeset(%{locked_at: nil})
    |> Repo.update()
    |> maybe_delete_author_cached()
  end

  @doc """
  Overrides the default Pow.Ecto.Context `create`.
  """
  @impl true
  def create(params) do
    case Accounts.get_author_by_email(params["email"]) do
      %Author{email: email} = author ->
        if author.email_confirmed_at,
          do:
            Oli.Email.create_email(
              email,
              "Account already exists",
              "account_already_exists.html",
              %{
                url:
                  Utils.ensure_absolute_url(
                    Routes.authoring_pow_session_path(OliWeb.Endpoint, :new)
                  ),
                forgot_password:
                  Utils.ensure_absolute_url(
                    Routes.authoring_pow_reset_password_reset_password_path(OliWeb.Endpoint, :new)
                  )
              }
            )
            |> Oli.Mailer.deliver_now()

        {:error, %{email: "has already been taken"}}

      _nil ->
        %Author{}
        |> Author.changeset(params)
        |> Repo.insert()
        |> case do
          {:ok, author} ->
            {:ok, author}

          {:error, error} ->
            {:error, error}
        end
    end
  end

  defp maybe_delete_author_cached(db_result) do
    case db_result do
      {:ok, author} = result ->
        Oli.AccountLookupCache.delete("author_#{author.id}")
        result

      error ->
        error
    end
  end

  @impl true
  def update(author, attrs),
    do: Accounts.update_author(author, attrs)
end
