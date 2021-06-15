defmodule OliWeb.Pow.UsersContext do
  @moduledoc """
  Custom module that handles pow users context for user.
  """

  use Pow.Ecto.Context,
    repo: Oli.Repo,
    user: Oli.Accounts.User

  @doc """
  Overrides the existing pow get_by/2 and ensures only
  independent learners are queried
  """
  @impl true
  def get_by(clauses) do
    clauses = Keyword.put_new(clauses, :independent_learner, true)

    pow_get_by(clauses)
  end
end
