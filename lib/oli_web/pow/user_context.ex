defmodule OliWeb.Pow.UserContext do
  @moduledoc """
  Custom module that handles pow users context for user.
  """

  use Pow.Ecto.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.User

  alias Oli.Repo
  alias Oli.Accounts.User

  @doc """
  Overrides the existing pow get_by/1 and ensures only
  independent learners are queried
  """
  @impl true
  def get_by(clauses) do
    clauses = Keyword.put_new(clauses, :independent_learner, true)

    pow_get_by(clauses)
  end

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def lock(user) do
    user
    |> User.lock_changeset()
    |> Repo.update()
  end

  @spec lock(map()) :: {:ok, map()} | {:error, map()}
  def unlock(user) do
    user
    |> User.noauth_changeset(%{locked_at: nil})
    |> Repo.update()
  end
end
