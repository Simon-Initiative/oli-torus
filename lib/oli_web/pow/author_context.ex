defmodule OliWeb.Pow.AuthorContext do
  @moduledoc """
  Custom module that handles pow users context for author.
  """

  use Pow.Ecto.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.Author

  alias Oli.Repo
  alias Oli.Accounts
  alias Oli.Accounts.Author

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def lock(user) do
    user
    |> Author.lock_changeset()
    |> Repo.update()
  end

  @spec unlock(map()) :: {:ok, map()} | {:error, map()}
  def unlock(user) do
    user
    |> Author.noauth_changeset(%{locked_at: nil})
    |> Repo.update()
  end

  @impl true
  def update(author, attrs),
    do: Accounts.update_author(author, attrs)
end
